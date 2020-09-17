defmodule Chromoid.Devices.Color do
  use GenServer
  require Logger
  import Chromoid.Devices.DeviceRegistry, only: [via: 1]
  @endpoint ChromoidWeb.Endpoint
  alias Phoenix.Socket.Broadcast

  def set_color(addr, rgb) do
    GenServer.call(via({__MODULE__, to_string(addr)}), {:set_color, rgb})
  end

  @doc false
  def start_link({device_id, address}) do
    GenServer.start_link(__MODULE__, {device_id, address}, name: via({__MODULE__, address}))
  end

  @impl GenServer
  def init({device_id, address}) do
    @endpoint.subscribe("devices:#{device_id}")
    {:ok, %{device_id: device_id, address: address, caller: nil}}
  end

  @impl GenServer
  def handle_call({:set_color, rgb}, from, state) do
    @endpoint.broadcast("devices:#{state.device_id}:#{state.address}", "set_color", %{color: rgb})
    {:noreply, %{state | caller: from}}
  end

  def handle_info(_, %{caller: nil} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        %Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: _leaves},
          topic: "devices:" <> _device_id
        },
        %{address: address} = state
      ) do
    state =
      Enum.reduce(joins, state, fn
        {^address, meta}, state ->
          Logger.info("Color Call complete")
          GenServer.reply(state.caller, meta)
          %{state | caller: nil}

        _, state ->
          state
      end)

    {:noreply, state}
  end
end
