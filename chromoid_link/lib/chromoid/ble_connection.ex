defmodule Chromoid.BLEConnection do
  use GenServer
  require Logger

  alias BlueHeron.HCI.Event.{
    LEMeta.ConnectionComplete,
    DisconnectionComplete
  }

  alias PhoenixClient.{Channel, Message}
  import Chromoid.BLEConnection.Registry, only: [via: 2]

  @socket Chromoid.Socket
  @topic "ble"

  def start_link({ctx, device_info}) do
    GenServer.start_link(__MODULE__, {ctx, device_info},
      name: via(device_info, device_info.address)
    )
  end

  def init({ctx, device_info}) do
    {:ok, conn} = BlueHeron.ATT.Client.start_link(ctx)
    send(self(), :join_channel)
    {:ok, %{channel: nil, ctx: ctx, conn: conn, device_info: device_info, color: nil}}
  end

  def terminate(reason, _) do
    Logger.error("BLE Crash: #{inspect(reason)}")
  end

  def handle_info(:join_channel, %{channel: nil} = state) do
    case Channel.join(@socket, "#{@topic}:#{state.device_info.address}", state.device_info) do
      {:ok, response, channel} ->
        Logger.info(
          "[#{inspect(state.device_info.address, base: :hex)}] Connected to ble channel: #{
            inspect(response)
          }"
        )

        {:noreply, %{state | channel: channel}}

      error ->
        Logger.error("Failed to connect to ble channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil}}
    end
  end

  # Sent when create_connection/2 is complete
  def handle_info(
        {BlueHeron.ATT.Client, conn, %ConnectionComplete{}},
        %{conn: conn, color: rgb} = state
      ) do
    Logger.info("Govee LED connection established: #{state.device_info.serial}")

    value =
      case state.device_info.serial do
        "H6125" <> _ ->
          <<0x33, 0x5, 0xB, rgb::24, 0xFF, 0x7F, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
            0x0>>

        "H6001" <> _ ->
          <<0x33, 0x5, 0x2, rgb::24, 0, rgb::24, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      end

    checksum = calculate_xor(value, 0)

    case BlueHeron.ATT.Client.write(state.conn, 0x0015, <<value::binary-19, checksum::8>>) do
      :ok ->
        BlueHeron.ATT.Client.create_connection_cancel(state.conn)
        PhoenixClient.Channel.push(state.channel, "color_state", %{color: rgb})
        Logger.info("Setting Govee LED Color: ##{inspect(rgb, base: :hex)}")
        {:noreply, state}

      error ->
        Logger.info("Failed to set Govee LED color: #{inspect(error)}")
        {:noreply, state}
    end

    {:noreply, state}
  end

  # Sent if a connection is dropped
  def handle_info({BlueHeron.ATT.Client, _, %DisconnectionComplete{reason_name: reason}}, state) do
    Logger.warn("Govee LED connection dropped: #{reason}")
    {:noreply, state}
  end

  def handle_info(%PhoenixClient.Message{event: "set_color", payload: %{"color" => rgb}}, state) do
    :ok =
      BlueHeron.ATT.Client.create_connection(state.conn, peer_address: state.device_info.address)

    {:noreply, %{state | color: rgb}}
  end

  def handle_info(%Message{}, state) do
    {:noreply, state}
  end

  defp calculate_xor(<<>>, checksum), do: checksum

  defp calculate_xor(<<x::8, rest::binary>>, checksum),
    do: calculate_xor(rest, :erlang.bxor(checksum, x))
end
