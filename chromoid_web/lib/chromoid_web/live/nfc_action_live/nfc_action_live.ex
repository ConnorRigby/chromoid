defmodule ChromoidWeb.NFCActionLive do
  use ChromoidWeb, :live_view
  # alias Phoenix.Socket.Broadcast

  alias Chromoid.Devices.{
    Device,
    NFC,
    NFC.ISO14443a
    # NFC.WebHook
  }

  @impl true
  def mount(%{"nfc_id" => nfc_id, "device_id" => device_id}, _session, socket) do
    %Device{} = device = Chromoid.Devices.get_device(device_id)
    %ISO14443a{} = nfc = NFC.get_iso14443a(nfc_id)
    changeset = NFC.change_action(nfc, %{})

    {:ok,
     socket
     |> assign(:device, device)
     |> assign(:nfc, nfc)
     |> assign(:changeset, changeset)
     |> load_actions()
     |> load_implementations()
     |> load_fields()
     |> load_docs()}
  end

  @impl true
  def handle_event("validate", %{"action" => attrs}, socket) do
    changeset = NFC.change_action(socket.assigns.nfc, attrs)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> load_fields()
     |> load_docs()}
  end

  def handle_event("save", %{"action" => attrs}, socket) do
    new_changeset = NFC.change_action(socket.assigns.nfc, %{})

    case NFC.new_action(socket.assigns.nfc, attrs) do
      {:ok, _nfc} ->
        {:noreply,
         socket
         |> put_flash(:info, "Action saved")
         |> assign(:changeset, new_changeset)
         |> load_actions()
         |> load_fields()
         |> load_docs()}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to save Action see errors below")
         |> assign(:changeset, changeset)
         |> load_actions()
         |> load_fields()
         |> load_docs()}
    end
  end

  def handle_event("delete", %{"action_id" => id}, socket) do
    case NFC.delete_action(socket.assigns.nfc, id) do
      {:ok, deleted} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deleted #{inspect(deleted)} action")}
    end
  end

  def load_actions(%{assigns: %{nfc: nfc}} = socket) do
    actions = NFC.load_actions(nfc)
    assign(socket, :actions, actions)
  end

  def load_implementations(socket) do
    impls =
      for {module, _} <- :code.all_loaded(),
          Chromoid.Devices.NFC.Action in (module.module_info(:attributes)[:behaviour] || []),
          do: module

    assign(socket, :implementations, impls)
  end

  def load_fields(socket) do
    module =
      Ecto.Changeset.get_field(socket.assigns.changeset, :module) ||
        hd(socket.assigns.implementations)

    assign(socket, :fields, module.fields)
  end

  def load_docs(socket) do
    module =
      Ecto.Changeset.get_field(
        socket.assigns.changeset,
        :module
      ) || Chromoid.Devices.NFC.LoggerAction

    case Code.fetch_docs(module) do
      {:docs_v1, _, :elixir, _, %{"en" => module_doc}, _, _} ->
        assign(socket, :moduledoc, module_doc)

      _ ->
        assign(socket, :moduledoc, "No documentation")
    end
  end
end
