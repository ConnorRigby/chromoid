defmodule ChromoidWeb.DeviceNFCLive do
  use ChromoidWeb, :live_view
  alias Chromoid.Devices

  alias Chromoid.Repo
  import Ecto.Query

  alias Chromoid.Devices.{
    Device,
    # NFC,
    NFC.ISO14443a
  }

  alias Phoenix.Socket.Broadcast

  @registration_timeout_ms 30_000

  @impl true
  def mount(%{"id" => device_id}, _session, socket) do
    %Device{} = device = Devices.get_device(device_id)
    socket.endpoint.subscribe("devices:#{device_id}:nfc")

    {:ok,
     socket
     |> assign(:device, device)
     |> load_nfc()
     |> assign(:register_mode, false)
     |> assign(:register_timer, nil)
     |> assign(:changeset, nil)}
  end

  @impl true
  def handle_event("register", _params, socket) do
    timer = Process.send_after(self(), :register_cancel, @registration_timeout_ms)
    changeset = ISO14443a.changeset(%ISO14443a{device_id: socket.assigns.device.id}, %{})

    {:noreply,
     socket
     |> assign(:register_mode, true)
     |> assign(:register_timer, timer)
     |> assign(:changeset, changeset)}
  end

  def handle_event("cancel-register", _params, socket) do
    if socket.assigns.register_timer, do: Process.cancel_timer(socket.assigns.register_timer)

    {:noreply,
     socket
     |> assign(:register_mode, false)
     |> assign(:register_timer, nil)
     |> assign(:changeset, nil)}
  end

  def handle_event("validate", attrs, socket) do
    changeset = ISO14443a.changeset(%ISO14443a{device_id: socket.assigns.device.id}, attrs)

    {:noreply,
     socket
     |> assign(:changeset, changeset)}
  end

  def handle_event("save", _attrs, socket) do
    # changeset = ISO14443a.changeset(%ISO14443a{device_id: socket.assigns.device.id}, attrs)
    new_changeset = ISO14443a.changeset(%ISO14443a{device_id: socket.assigns.device.id}, %{})

    case Repo.insert(socket.assigns.changeset) do
      {:ok, _nfc} ->
        if socket.assigns.register_timer, do: Process.cancel_timer(socket.assigns.register_timer)
        timer = Process.send_after(self(), :register_cancel, @registration_timeout_ms)

        {:noreply,
         socket
         |> put_flash(:info, "Registered")
         |> load_nfc()
         |> assign(:register_timer, timer)
         |> assign(:changeset, new_changeset)}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to register card see errors")
         |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_info(:register_cancel, socket) do
    {:noreply,
     socket
     |> assign(:register_mode, false)
     |> assign(:register_timer, nil)
     |> assign(:changeset, nil)}
  end

  def handle_info(
        %Broadcast{event: "iso14443a", payload: attrs},
        %{assigns: %{register_mode: false}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(
       "info",
       "Card with uid of #{attrs["abtUid"]} scanned but not registering. ignoring."
     )}
  end

  def handle_info(%Broadcast{event: "iso14443a", payload: attrs}, socket) do
    changeset = ISO14443a.changeset(%ISO14443a{device_id: socket.assigns.device.id}, attrs)

    {:noreply,
     socket
     |> assign(:changeset, changeset)}
  end

  def load_nfc(socket) do
    device_id = socket.assigns.device.id
    nfc = Repo.all(from nfc in ISO14443a, where: nfc.device_id == ^device_id)
    assign(socket, :nfc, nfc)
  end
end
