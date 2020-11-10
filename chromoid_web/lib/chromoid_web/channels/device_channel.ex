defmodule ChromoidWeb.DeviceChannel do
  use ChromoidWeb, :channel
  require Logger
  alias Chromoid.Devices.Presence
  alias Phoenix.Socket.Broadcast
  alias Chromoid.Devices.Job

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
        online_at: DateTime.utc_now(),
        last_communication: DateTime.utc_now(),
        status: "connected",
        storage: nil,
        path: nil,
        progress: nil,
        job: nil
      })

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "photo_request", payload: payload}, socket) do
    Logger.info("Requesting Photo")
    push(socket, "photo_request", payload)
    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "freenect", payload: payload}, socket) do
    Logger.info("Sending freenect ioctl")
    push(socket, "freenect", payload)
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
    socket.endpoint.broadcast("devices:#{socket.assigns.device.id}", "photo_response", response)
    {:reply, {:ok, %{}}, socket}
  end

  def handle_in(
        "progress_report",
        %{"storage" => storage, "path" => path, "progress" => progress},
        socket
      ) do
    Logger.info("received progress report: #{storage} #{path} #{progress}")

    socket.endpoint.broadcast("devices:#{socket.assigns.device.id}", "progress_report", %{
      storage: storage,
      path: path,
      progress: progress
    })

    Presence.update(
      self(),
      "devices",
      "#{socket.assigns.device.id}",
      fn old ->
        %{old | storage: storage, path: path, progress: progress}
      end
    )

    {:reply, {:ok, %{}}, socket}
  end

  def handle_in("job", attrs, socket) do
    job =
      Job.changeset(%Job{}, attrs)
      |> Ecto.Changeset.apply_changes()

    Presence.update(
      self(),
      "devices",
      "#{socket.assigns.device.id}",
      fn old ->
        %{old | job: job}
      end
    )

    {:noreply, socket}
  end
end
