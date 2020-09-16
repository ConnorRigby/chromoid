defmodule ChromoidWeb.DeviceChannel do
  use ChromoidWeb, :channel
  alias Chromoid.Devices.Presence

  def join(_topic, _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(self(), "devices", "#{socket.assigns.device.id}", %{
        online_at: DateTime.utc_now()
      })

    {:noreply, socket}
  end
end
