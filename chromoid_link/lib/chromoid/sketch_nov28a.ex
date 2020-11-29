defmodule SketchNov28a do
  use GenServer
  require Logger

  @socket Chromoid.Socket
  @topic "ble"
  alias PhoenixClient.{Channel, Message}

  def start_link(device) do
    GenServer.start_link(__MODULE__, device, name: __MODULE__)
  end

  def set_color(color) do
    GenServer.call(__MODULE__, {:set_color, color})
  end

  @impl GenServer
  def init(device) do
    {:ok, uart} = Circuits.UART.start_link()
    send(self(), :open_uart)
    send(self(), :join_channel)

    {:ok, %{uart: uart, device: device, open: false, caller: nil, channel: nil, address: "69:69:69:69:69:69", color: nil}}
  end

  @impl GenServer
  def handle_info(:open_uart, state) do
    case Circuits.UART.open(state.uart, state.device,
           active: true,
           speed: 115_200,
           framing: Circuits.UART.Framing.None
         ) do
      :ok ->
        Logger.info("Opened #{state.device}")
        {:noreply, %{state | open: true}}

      error ->
        Logger.error("Failed to open #{state.device}: #{inspect(error)}")
        Process.send_after(self(),:open_uart, 5000)
        {:noreply, %{state | open: false}}
    end
  end

  def handle_info(:join_channel, %{channel: nil} = state) do
    case Channel.join(@socket, "#{@topic}:#{state.address}", %{}) do
      {:ok, response, channel} ->
        Logger.info("Connected to ble channel: #{inspect(response)}")

        {:noreply, %{state | channel: channel}}

      error ->
        Logger.error("Failed to connect to ble channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil}}
    end
  end

  def handle_info(
        %PhoenixClient.Message{event: "set_color", payload: %{"color" => rgb}},
        %{open: true} = state
      ) do
    Circuits.UART.write(state.uart, <<4::16, 0x69, rgb::24>>)
    PhoenixClient.Channel.push(state.channel, "color_state", %{color: rgb})
    {:noreply, state}
  end

  def handle_info(%Message{}, state) do
    {:noreply, state}
  end

  def handle_info({:circuits_uart, _, <<len::16, data::binary-size(len)>>}, state) do
    handle_data(data, state)
  end

  @impl GenServer
  def handle_call({:set_color, color}, from, state) do
    Circuits.UART.write(state.uart, <<4::16, 0x69, color::24>>)
    {:noreply, %{state | caller: from}}
  end

  def handle_data(<<0x69, result>>, state) do
    if(state.caller) do
      GenServer.reply(state.caller, result_code_to_atom(result))
    end
    {:noreply, %{state | caller: nil}}
  end

  def result_code_to_atom(0), do: :ok
end
