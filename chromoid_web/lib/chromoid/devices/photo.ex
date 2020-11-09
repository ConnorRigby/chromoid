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
    {:ok, %{device_id: device_id, caller: nil}}
  end

  @impl GenServer
  def handle_call(:request_photo, from, state) do
    @endpoint.broadcast("devices:#{state.device_id}", "photo_request", %{})
    {:noreply, %{state | caller: from}}
  end

  @impl GenServer
  def handle_info(%Broadcast{}, %{caller: nil} = state) do
    {:noreply, state}
  end

  def handle_info(
        %Broadcast{event: "photo_response", payload: %{"content" => jpeg_base64} = payload},
        state
      ) do
    GenServer.reply(state.caller, {:ok, %{payload | "content" => Base.decode64!(jpeg_base64)}})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info(%Broadcast{}, state) do
    {:noreply, state}
  end
end
