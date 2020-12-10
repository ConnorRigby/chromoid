defmodule ChromoidWeb.RelayChannel do
  require Logger
  use ChromoidWeb, :channel
  alias Chromoid.Devices.Presence
  alias Phoenix.Socket.Broadcast
  alias Chromoid.Devices.RelayStatus

  @impl true
  def join("relay:" <> addr, params, socket) do
    case Chromoid.Devices.RelaySupervisor.start_child({socket.assigns.device.id, addr}) do
      {:ok, pid} ->
        socket.endpoint.subscribe("devices:#{socket.assigns.device.id}:relay-#{addr}")
        {:ok, assign(socket, :address, addr) |> assign(params) |> assign(:relay_pid, pid)}

      # hack due to hot code reload typo. Delete me one day
      {:error, {:already_started, pid}} ->
        {:ok, assign(socket, :address, addr) |> assign(params) |> assign(:relay_pid, pid)}

      error ->
        error
    end

    send(self(), :after_join)
    {:ok, assign(socket, :address, addr)}
  end

  @impl true
  def terminate(_, socket) do
    if pid = socket.assigns[:relay_pid] do
      Chromoid.Devices.RelaySupervisor.stop_child(pid)
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(
        self(),
        "devices:#{socket.assigns.device.id}",
        "relay-#{socket.assigns.address}",
        %RelayStatus{}
      )

    {:noreply, socket}
  end

  def handle_info(%Broadcast{event: "set_state", payload: payload}, socket) do
    Logger.info("Sending relay ioctl")
    push(socket, "relay_status", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("relay_status", attrs, socket) do
    relay_status =
      RelayStatus.changeset(%RelayStatus{}, attrs)
      |> Ecto.Changeset.apply_changes()

    {:ok, _} =
      Presence.update(
        self(),
        "devices:#{socket.assigns.device.id}",
        "relay-#{socket.assigns.address}",
        relay_status
      )

    {:noreply, socket}
  end
end
