defmodule ChromoidWeb.NFCChannel do
  require Logger
  use ChromoidWeb, :channel
  # alias Chromoid.Devices.Presence
  # alias Phoenix.Socket.Broadcast

  @impl true
  def join("nfc", _params, socket) do
    # socket.endpoint.subscribe("devices:#{socket.assigns.device.id}:nfc")
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def terminate(reason, _socket) do
    Logger.error("NFC CHannel crash: #{inspect(reason)}")
  end

  @impl true
  def handle_info(:after_join, socket) do
    # {:ok, _} =
    #   Presence.track(
    #     self(),
    #     "devices:#{socket.assigns.device.id}",
    #     "nfc",
    #     %{}
    #   )

    {:noreply, socket}
  end

  @impl true
  def handle_in("iso14443a", attrs, socket) do
    Logger.info("iso14443a scan: #{inspect(attrs)}")
    socket.endpoint.broadcast("devices:#{socket.assigns.device.id}:nfc", "iso14443a", attrs)
    {:noreply, socket}
  end
end
