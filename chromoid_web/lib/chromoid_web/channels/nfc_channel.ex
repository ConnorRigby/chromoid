defmodule ChromoidWeb.NFCChannel do
  require Logger
  use ChromoidWeb, :channel
  alias Chromoid.Devices.NFC

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
    {:noreply, socket}
  end

  @impl true
  def handle_in("iso14443a", attrs, socket) do
    Logger.info("iso14443a scan: #{inspect(attrs)}")
    socket.endpoint.broadcast("devices:#{socket.assigns.device.id}:nfc", "iso14443a", attrs)

    if iso14443a = NFC.get_iso14443a_by_uid(socket.assigns.device.id, attrs["abtUid"]) do
      socket.endpoint.broadcast("nfc", "iso14443a", iso14443a)
    end

    {:noreply, socket}
  end
end
