defmodule Chromoid.Devices.Relay do
  use GenServer
  require Logger
  import Chromoid.Devices.DeviceRegistry, only: [via: 1]
  @endpoint ChromoidWeb.Endpoint
  alias Phoenix.Socket.Broadcast

  def set_state(%{id: device_id}, addr, state) do
    set_state(device_id, addr, state)
  end

  def set_state(device_id, addr, state) do
    GenServer.call(via({__MODULE__, device_id, to_string(addr)}), {:set_state, state})
  end

  @doc false
  def start_link({device_id, address}) do
    GenServer.start_link(__MODULE__, {device_id, address},
      name: via({__MODULE__, device_id, address})
    )
  end

  @impl GenServer
  def init({device_id, address}) do
    @endpoint.subscribe("devices:#{device_id}")
    {:ok, %{device_id: device_id, address: address, caller: nil}}
  end

  @impl GenServer
  def handle_call({:set_state, relay_state}, from, state) do
    @endpoint.broadcast("devices:#{state.device_id}:relay-#{state.address}", "set_state", %{
      state: relay_state
    })

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
        {"relay-" <> ^address, meta}, state ->
          Logger.info("Relay ioctl complete")
          GenServer.reply(state.caller, meta)
          %{state | caller: nil}

        _, state ->
          state
      end)

    {:noreply, state}
  end
end
