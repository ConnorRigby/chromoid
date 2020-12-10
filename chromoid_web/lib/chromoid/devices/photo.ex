defmodule Chromoid.Devices.Photo do
  # jpeg = Base.decode64!(jpeg_base64)
  use GenServer
  require Logger
  import Chromoid.Devices.DeviceRegistry, only: [via: 1]
  @endpoint ChromoidWeb.Endpoint
  alias Phoenix.Socket.Broadcast

  def request_photo(%Chromoid.Devices.Device{camera_differ_id: nil, id: id}) do
    request_photo(id)
  end

  def request_photo(%Chromoid.Devices.Device{camera_differ_id: id}) do
    request_photo(id)
  end

  def request_photo(device_id) do
    GenServer.call(via({__MODULE__, device_id}), :request_photo)
  end

  def start_link(device_id) do
    GenServer.start_link(__MODULE__, device_id, name: via({__MODULE__, device_id}))
  end

  @impl GenServer
  def init(device_id) do
    @endpoint.subscribe("devices:#{device_id}")
    Logger.metadata(device_id: device_id)
    {:ok, %{device_id: device_id, caller: nil, timer: nil}}
  end

  @impl GenServer
  def handle_call(:request_photo, from, state) do
    @endpoint.broadcast("devices:#{state.device_id}", "photo_request", %{})
    timer = Process.send_after(self(), :timeout, 3000)
    {:noreply, %{state | caller: from, timer: timer}}
  end

  @impl GenServer
  def handle_info(%Broadcast{}, %{caller: nil} = state) do
    {:noreply, state}
  end

  def handle_info(
        %Broadcast{event: "photo_response", payload: %{"content" => jpeg_base64} = payload},
        state
      ) do
    if state.timer, do: Process.cancel_timer(state.timer)
    GenServer.reply(state.caller, {:ok, %{payload | "content" => Base.decode64!(jpeg_base64)}})
    {:noreply, %{state | caller: nil, timer: nil}}
  end

  def handle_info(
        %Broadcast{event: "photo_response", payload: %{"error" => reason}},
        state
      ) do
    if state.timer, do: Process.cancel_timer(state.timer)
    GenServer.reply(state.caller, {:error, reason})
    {:noreply, %{state | caller: nil, timer: nil}}
  end

  def handle_info(%Broadcast{}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    GenServer.reply(state.caller, {:error, "timeout"})
    {:noreply, %{state | caller: nil, timer: nil}}
  end
end
