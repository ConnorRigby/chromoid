defmodule ChromoidWeb.DeviceChannel do
  use ChromoidWeb, :channel
  require Logger
  alias Chromoid.Devices.Presence
  alias Phoenix.Socket.Broadcast

  def join(_topic, _params, socket) do
    send(self(), :after_join)
    socket.endpoint.subscribe("devices:#{socket.assigns.device.id}")

    case Chromoid.Devices.Photo.start_link(socket.assigns.device.id) do
      {:ok, pid} ->
        {:ok, assign(socket, :photo_pid, pid)}

      error ->
        error
    end
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(self(), "devices", "#{socket.assigns.device.id}", %{
        online_at: DateTime.utc_now()
      })

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "photo_request", payload: payload}, socket) do
    Logger.info("Requesting Photo")
    push(socket, "photo_request", payload)
    {:noreply, socket}
  end

  def handle_info(%Broadcast{}, socket) do
    {:noreply, socket}
  end

  def handle_in(
        "photo_response",
        %{"content" => _jpeg_base64, "name" => _name} = response,
        socket
      ) do
    # broadcast_from!(socket, "photo_response", response)
    socket.endpoint.broadcast("devices:#{socket.assigns.device.id}", "photo_response", response)
    {:reply, {:ok, %{}}, socket}
  end
end
