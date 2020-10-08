defmodule ChromoidWeb.DeviceLive do
  use ChromoidWeb, :live_view
  alias Chromoid.{Devices, Devices.Presence}
  alias Phoenix.Socket.Broadcast

  @impl true
  def mount(_params, _session, socket) do
    :ok = socket.endpoint.subscribe("devices")
    # :ok = ChromoidWeb.Endpoint.subscribe("devices")
    send(self(), :WTF)
    {:ok, assign(socket, :devices, [])}

    # devices =
    #   sync_devices(Chromoid.Repo.all(Devices.Device), %{
    #     joins: Presence.list("devices"),
    #     leaves: %{}
    #   })

    # {:ok,
    #  socket
    #  |> assign(:devices, devices)}
  end

  @impl true
  def handle_info(%Broadcast{event: "presence_diff", topic: "devices", payload: diff}, socket) do
    raise "??????"
    devices = sync_devices(Chromoid.Repo.all(Devices.Device), diff)

    {:ok,
     socket
     |> assign(:devices, devices)}
  end

  defp sync_devices(devices, %{joins: joins, leaves: leaves}) do
    for device <- devices do
      id = to_string(device.id)

      cond do
        meta = joins[id] ->
          fields = [
            :last_communication,
            :online_at,
            :status
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

        true ->
          device
          |> Map.put(:last_communication, nil)
          |> Map.put(:status, "offline")
      end
    end
  end
end
