defmodule ChromoidWeb.DeviceSocket do
  use Phoenix.Socket
  require Logger

  ## Channels
  channel "device", ChromoidWeb.DeviceChannel
  channel "ble:*", ChromoidWeb.BLEChannel
  channel "relay:*", ChromoidWeb.RelayChannel
  channel "nfc", ChromoidWeb.NFCChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    with {:ok, token} <- Base.url_decode64(token, padding: false),
         token <- :crypto.hash(:sha256, token),
         %Chromoid.Devices.Device{} = device <- Chromoid.Devices.get_device_by_token(token) do
      {:ok,
       socket
       |> assign(:device, device)}
    else
      error ->
        Logger.error("Could not authenticate device: #{inspect(error)}")
        :error
    end
  end

  def connect(_, _, _) do
    Logger.error("Could not authenticate device: no token supplied")
    :error
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     ChromoidWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "device_socket:#{socket.assigns.device.id}"
end
