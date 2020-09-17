defmodule Chromoid.BLEConnection do
  use GenServer
  require Logger

  alias BlueHeron.HCI.Event.{
    LEMeta.ConnectionComplete,
    DisconnectionComplete
  }

  alias PhoenixClient.{Channel, Message}
  import Chromoid.BLEConnection.Registry, only: [via: 1]

  @socket Chromoid.Socket
  @topic "ble"

  @doc false
  def start_link({ctx, device_info}) do
    GenServer.start_link(__MODULE__, {ctx, device_info}, name: via(device_info.address))
  end

  @impl GenServer
  def init({ctx, device_info}) do
    Logger.metadata(ble_address: inspect(device_info.address, base: :hex))
    Logger.info("BLE Channel init")
    {:ok, conn} = BlueHeron.ATT.Client.start_link(ctx)
    send(self(), :join_channel)
    send(self(), :ble_connect)

    {:ok,
     %{
       channel: nil,
       ctx: ctx,
       conn: conn,
       device_info: device_info,
       color: nil,
       ble_connected?: false
     }}
  end

  @impl GenServer
  def terminate(reason, _) do
    Logger.error("BLE Crash: #{inspect(reason)}")
  end

  @impl GenServer
  def handle_info(:join_channel, %{channel: nil} = state) do
    case Channel.join(@socket, "#{@topic}:#{state.device_info.address}", state.device_info) do
      {:ok, response, channel} ->
        Logger.info("Connected to ble channel: #{inspect(response)}")

        {:noreply, %{state | channel: channel}}

      error ->
        Logger.error("Failed to connect to ble channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil}}
    end
  end

  def handle_info(:ble_connect, %{ble_connected?: false} = state) do
    :ok =
      BlueHeron.ATT.Client.create_connection(state.conn, peer_address: state.device_info.address)

    Logger.info("Create connection request complete")
    {:noreply, state}
  end

  # Sent when create_connection/2 is complete
  def handle_info(
        {BlueHeron.ATT.Client, conn, %ConnectionComplete{connection_handle: handle}},
        %{conn: conn} = state
      ) do
    Logger.info("Govee LED connection established: #{state.device_info.serial}")

    Logger.metadata(
      ble_address: inspect(state.device_info.address, base: :hex),
      connection_handle: inspect(handle, base: :hex)
    )

    {:noreply, %{state | ble_connected?: true}}
  end

  # Sent if a connection is dropped
  def handle_info({BlueHeron.ATT.Client, _, %DisconnectionComplete{reason_name: reason}}, state) do
    Logger.warn("Govee LED connection dropped: #{reason}")

    Logger.metadata(
      ble_address: inspect(state.device_info.address, base: :hex),
      connection_handle: nil
    )

    {:noreply, %{state | ble_connected?: false}}
  end

  def handle_info(
        %PhoenixClient.Message{event: "set_color", payload: %{"color" => rgb}},
        %{ble_connected?: true} = state
      ) do
    payload = build_payload(state, rgb)

    checksum = calculate_xor(payload, 0)

    case BlueHeron.ATT.Client.write(state.conn, 0x0015, <<payload::binary-19, checksum::8>>) do
      :ok ->
        Logger.info("Wrote payload")
        # :ok = BlueHeron.ATT.Client.disconnect(state.conn, 0x15)
        # Logger.info "Disconnect sent"
        PhoenixClient.Channel.push(state.channel, "color_state", %{color: rgb})
        Logger.info("Set Govee LED Color: ##{inspect(rgb, base: :hex)}")
        {:noreply, %{state | color: rgb}}

      error ->
        Logger.info("Failed to set Govee LED color: #{inspect(error)}")
        PhoenixClient.Channel.push(state.channel, "error", %{message: inspect(error)})
        {:noreply, state}
    end
  end

  def handle_info(%Message{}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    PhoenixClient.Channel.push(state.channel, "error", %{message: "Timeout"})
    {:noreply, state}
  end

  defp calculate_xor(<<>>, checksum), do: checksum

  defp calculate_xor(<<x::8, rest::binary>>, checksum),
    do: calculate_xor(rest, :erlang.bxor(checksum, x))

  defp build_payload(state, rgb) do
    case state.device_info.serial do
      "H6125" <> _ ->
        <<0x33, 0x5, 0xB, rgb::24, 0xFF, 0x7F, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
          0x0>>

      "H6001" <> _ ->
        <<0x33, 0x5, 0x2, rgb::24, 0, rgb::24, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
    end
  end
end
