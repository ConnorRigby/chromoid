defmodule ChromoidWeb.BLEChannel do
  use ChromoidWeb, :channel
  alias Chromoid.Devices.Presence
  alias Phoenix.Socket.Broadcast

  def join("ble:" <> addr, params, socket) do
    send(self(), :after_join)

    case Chromoid.Devices.BLESupervisor.start_child({socket.assigns.device.id, addr}) do
      {:ok, pid} ->
        socket.endpoint.subscribe("devices:#{socket.assigns.device.id}:#{addr}")
        {:ok, assign(socket, :address, addr) |> assign(params) |> assign(:color_pid, pid)}

      error ->
        error
    end
  end

  def terminate(_, %{assigns: %{color_pid: pid}}) do
    Chromoid.Devices.BLESupervisor.stop_child(pid)
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(
        self(),
        "devices:#{socket.assigns.device.id}",
        "#{socket.assigns.address}",
        %{
          online_at: DateTime.utc_now(),
          device_id: socket.assigns.device.id,
          serial: socket.assigns["serial"],
          color: 0x000000,
          error: nil
        }
      )

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "set_color", payload: payload}, socket) do
    push(socket, "set_color", payload)
    {:noreply, socket}
  end

  def handle_info(%Broadcast{}, socket) do
    {:noreply, socket}
  end

  def handle_in("color_state", %{"color" => rgb}, socket) do
    IO.inspect(rgb, label: "handle_in")

    Presence.update(
      self(),
      "devices:#{socket.assigns.device.id}",
      "#{socket.assigns.address}",
      fn old ->
        %{old | color: rgb, error: nil}
      end
    )

    {:reply, {:ok, %{}}, socket}
  end

  def handle_in("error", %{"message" => message}, socket) do
    Presence.update(
      self(),
      "devices:#{socket.assigns.device.id}",
      "#{socket.assigns.address}",
      &Map.put(&1, :error, message)
    )

    {:reply, {:ok, %{}}, socket}
  end
end
