defmodule ChromoidWeb.BLEChannel do
  use ChromoidWeb, :channel
  alias Chromoid.Devices.Presence
  alias Phoenix.Socket.Broadcast

  def join("ble:" <> addr, params, socket) do
    send(self(), :after_join)
    IO.inspect("devices:#{socket.assigns.device.id}:#{addr}")
    socket.endpoint.subscribe("devices:#{socket.assigns.device.id}:#{addr}")
    {:ok, assign(socket, :address, addr) |> assign(params)}
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
          color: 0x000000
        }
      )

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "set_color", payload: payload}, socket) do
    IO.inspect(payload, label: "????")
    push(socket, "set_color", payload)
    {:noreply, socket}
  end

  def handle_info(%Broadcast{} = bc, socket) do
    IO.inspect(bc, label: "fail")
    {:noreply, socket}
  end

  def handle_in("color_state", %{"color" => rgb}, socket) do
    # Presence.update(self(), "devices:#{socket.assigns.device.id}", "#{socket.assigns.address}", &Map.put(&1, :color, rgb))
    {:reply, {:ok, %{}}, socket}
  end
end
