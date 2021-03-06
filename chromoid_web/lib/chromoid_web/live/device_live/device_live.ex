defmodule ChromoidWeb.DeviceLive do
  use ChromoidWeb, :live_view
  alias Chromoid.{Devices, Devices.Presence}
  alias Phoenix.Socket.Broadcast
  require Logger
  import Chromoid.Devices.Ble.Utils

  @impl true
  def mount(params, _session, socket) do
    :ok = socket.endpoint.subscribe("devices")
    {:ok, assign(socket, :devices, [])}

    devices =
      sync_devices(Chromoid.Repo.all(Devices.Device), %{
        joins: Presence.list("devices"),
        leaves: %{}
      })

    modal_device =
      if params["id"] do
        device = Devices.get_device(params["id"])

        meta =
          Chromoid.Devices.Presence.list("devices")[params["id"]] ||
            %{
              last_communication: nil,
              status: "offline",
              job: nil,
              relay_status: nil
            }

        Map.merge(device, meta)
      end

    {:ok,
     socket
     |> assign(:devices, devices)
     |> assign(:modal_device_id, params["id"])
     |> assign(:modal_device, modal_device)
     |> assign(:ble, %{})
     |> assign(:relays, %{})
     |> assign(:colors, [
       "#2196F3",
       "#009688",
       "#9C27B0",
       "#FFEB3B",
       "#4CAF50",
       "#2d3748",
       "#f56565",
       "#ed64a6"
     ])}
  end

  @impl true
  def handle_info(%Broadcast{event: "presence_diff", topic: "devices", payload: diff}, socket) do
    devices = sync_devices(Chromoid.Repo.all(Devices.Device), diff)

    modal_device =
      if socket.assigns.modal_device do
        meta =
          Chromoid.Devices.Presence.list("devices")[to_string(socket.assigns.modal_device.id)] ||
            %{
              last_communication: nil,
              status: "offline",
              job: nil,
              relay_status: nil
            }

        Map.merge(socket.assigns.modal_device, meta)
      end

    Logger.info("modal_device: #{inspect(modal_device)}")

    {:noreply,
     socket
     |> assign(:devices, devices)
     |> assign(:modal_device_id, modal_device.id)
     |> assign(:modal_device, modal_device)}
  end

  def handle_info(
        %Broadcast{event: "presence_diff", topic: "devices:" <> _device_id, payload: diff},
        socket
      ) do
    ble =
      diff.leaves
      |> Enum.reduce(socket.assigns.ble, fn
        {"ble-" <> addr, _ble_dev}, ble_devs ->
          Map.delete(ble_devs, addr)

        {"relay-" <> _, _}, ble_devs ->
          ble_devs
      end)

    ble =
      diff.joins
      |> Enum.reduce(ble, fn
        {"ble-" <> addr_string, ble_dev}, ble_devs ->
          Map.put(ble_devs, addr_string, ble_dev)

        {"relay-" <> _, _}, ble_devs ->
          ble_devs
      end)

    relays =
      diff.leaves
      |> Enum.reduce(socket.assigns.relays, fn
        {"relay-" <> addr, _relays_dev}, relays_devs ->
          Map.delete(relays_devs, addr)

        {"ble-" <> _, _}, relays_devs ->
          relays_devs
      end)

    relays =
      diff.joins
      |> Enum.reduce(relays, fn
        {"relay-" <> addr_string, relays_dev}, relays_devs ->
          Map.put(relays_devs, addr_string, relays_dev)

        {"ble-" <> _, _}, relays_devs ->
          relays_devs
      end)

    {:noreply,
     socket
     |> assign(:ble, ble)
     |> assign(:relays, relays)}
  end

  def handle_info(
        %Broadcast{event: "relay_status"},
        socket
      ) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_modal", %{"device_id" => device_id}, socket) do
    :ok = socket.endpoint.subscribe("devices:#{device_id}")
    device = Chromoid.Devices.get_device(device_id)
    ble = Chromoid.Devices.Presence.list_bles(device)
    relays = Chromoid.Devices.Presence.list_relays(device)

    meta =
      Chromoid.Devices.Presence.list("devices")[to_string(device_id)] ||
        %{
          last_communication: nil,
          status: "offline",
          job: nil
        }

    {:noreply,
     socket
     |> assign(:modal_device_id, device_id)
     |> assign(:modal_device, Map.merge(device, meta))
     |> assign(:ble, ble)
     |> assign(:relays, relays)}
  end

  def handle_event("hide_modal", _, socket) do
    :ok = socket.endpoint.unsubscribe("devices:#{socket.assigns.modal_device_id}")

    {:noreply,
     socket
     |> assign(:modal_device_id, nil)
     |> assign(:ble, %{})
     |> assign(:relays, %{})}
  end

  def handle_event("color_picker", %{"address" => address, "color" => color_arg}, socket) do
    color = decode_color_arg(color_arg)

    Logger.info(
      "Sending color change command: #{format_address(address)} #{inspect(color, base: :hex)}"
    )

    _meta = Chromoid.Devices.Color.set_color(address, color)

    {:noreply, socket}
  end

  def handle_event("toggle_relay", %{"address" => address, "state" => state}, socket) do
    Logger.info("Sending relay change command: #{address}")
    _meta = Chromoid.Devices.Relay.set_state(socket.assigns.modal_device, address, state)
    {:noreply, socket}
  end

  defp sync_devices(devices, %{joins: joins, leaves: leaves}) do
    for device <- devices do
      id = to_string(device.id)

      cond do
        meta = joins[id] ->
          fields = [
            :last_communication,
            :online_at,
            :status,
            :job
          ]

          updates = Map.take(meta, fields)
          Map.merge(device, updates)

        leaves[id] ->
          # We're counting a device leaving as its last_communication. This is
          # slightly inaccurate to set here, but only by a minuscule amount
          # and saves DB calls and broadcasts
          disconnect_time = DateTime.truncate(DateTime.utc_now(), :second)

          device
          |> Map.put(:last_communication, disconnect_time)
          |> Map.put(:status, "offline")
          |> Map.put(:job, nil)

        true ->
          device
          |> Map.put(:last_communication, nil)
          |> Map.put(:status, "offline")
          |> Map.put(:job, nil)
      end
    end
  end

  defp decode_color_arg("#" <> hex_str) do
    String.to_integer(hex_str, 16)
  end

  defp decode_color_arg("white"), do: 0xFFFFFF
  defp decode_color_arg("silver"), do: 0xC0C0C0
  defp decode_color_arg("gray"), do: 0x808080
  defp decode_color_arg("black"), do: 0x000000
  defp decode_color_arg("red"), do: 0xFF0000
  defp decode_color_arg("maroon"), do: 0x800000
  defp decode_color_arg("yellow"), do: 0xFFFF00
  defp decode_color_arg("olive"), do: 0x808000
  defp decode_color_arg("lime"), do: 0x00FF00
  defp decode_color_arg("green"), do: 0x008000
  defp decode_color_arg("aqua"), do: 0x00FFFF
  defp decode_color_arg("teal"), do: 0x008080
  defp decode_color_arg("blue"), do: 0x0000FF
  defp decode_color_arg("navy"), do: 0x000080
  defp decode_color_arg("fuchsia"), do: 0xFF00FF
  defp decode_color_arg("purple"), do: 0x800080
end
