defmodule ChromoidWeb.BLEChannel do
  use ChromoidWeb, :channel
  alias Chromoid.Devices.Presence
  alias Phoenix.Socket.Broadcast

  def normalize_addr(<<a::2*8, ":", b::2*8, ":", c::2*8, ":", d::2*8, ":", e::2*8, ":", f::2*8>>) do
    <<addr::48>> = <<a, b, c, d, e, f>>
    "#{addr}"
  end

  def normalize_addr(addr), do: to_string(addr)

  def join("ble:" <> addr, params, socket) do
    send(self(), :after_join)
    addr = normalize_addr(addr)

    case Chromoid.Devices.BLESupervisor.start_child({socket.assigns.device.id, addr}) do
      {:ok, pid} ->
        socket.endpoint.subscribe("devices:#{socket.assigns.device.id}:#{addr}")
        {:ok, assign(socket, :address, addr) |> assign(params) |> assign(:color_pid, pid)}

      # hack due to hot code reload typo. Delete me one day
      {:error, {:already_started, pid}} ->
        {:ok, assign(socket, :address, addr) |> assign(params) |> assign(:color_pid, pid)}

      error ->
        error
    end
  end

  def terminate(_, socket) do
    if pid = socket.assigns[:color_pid] do
      Chromoid.Devices.BLESupervisor.stop_child(pid)
    end
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
