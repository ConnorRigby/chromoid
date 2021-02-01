defmodule ChromoidWeb.NFCWebhookLive do
  use ChromoidWeb, :live_view
  alias Phoenix.Socket.Broadcast

  alias Chromoid.Devices.{
    Device,
    NFC,
    NFC.ISO14443a,
    NFC.WebHook
  }

  @impl true
  def mount(%{"nfc_id" => nfc_id, "device_id" => device_id}, _session, socket) do
    %Device{} = device = Chromoid.Devices.get_device(device_id)
    %ISO14443a{} = nfc = NFC.get_iso14443a(nfc_id)
    changeset = NFC.change_webhook(nfc, %{})

    {:ok,
     socket
     |> assign(:device, device)
     |> assign(:nfc, nfc)
     |> load_webhooks()
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"web_hook" => attrs}, socket) do
    changeset = NFC.change_webhook(socket.assigns.nfc, attrs)

    {:noreply,
     socket
     |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"web_hook" => attrs}, socket) do
    new_changeset = NFC.change_webhook(socket.assigns.nfc, attrs)

    case NFC.new_webhook(socket.assigns.nfc, attrs) do
      {:ok, _nfc} ->
        {:noreply,
         socket
         |> put_flash(:info, "Webhook saved")
         |> load_webhooks()
         |> assign(:changeset, new_changeset)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save Webhook see errors below")
         |> assign(:changeset, changeset)}
    end
  end

  def handle_event("delete", %{"webhook_id" => id}, socket) do
    case NFC.delete_webhook(socket.assigns.nfc, id) do
      {:ok, deleted} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deleted #{deleted.url} webhook")
         |> load_webhooks()}
    end
  end

  def load_webhooks(%{assigns: %{nfc: nfc}} = socket) do
    webhooks = NFC.load_webhooks(nfc)
    assign(socket, :webhooks, webhooks)
  end
end
