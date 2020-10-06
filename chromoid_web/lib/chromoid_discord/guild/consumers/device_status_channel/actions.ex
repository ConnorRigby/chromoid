defmodule ChromoidDiscord.Guild.DeviceStatusChannel.Actions do
  import Nostrum.Struct.Embed
  @endpoint ChromoidWeb.Endpoint
  import ChromoidWeb.Router.Helpers, only: [device_url: 3]
  import Chromoid.Devices.Ble.Utils
  alias Chromoid.Devices.Color
  alias Chromoid.Repo

  def device_list_action(message) do
    for {id, meta} <- Chromoid.Devices.Presence.list("devices") do
      device = Repo.get!(Chromoid.Devices.Device, id)
      device_info_action(message, device, meta)
    end
  end

  def device_info_action(message, device, nil) do
    error_action(message, "Device `#{device.serial}` is not online")
  end

  def device_info_action(message, device, meta) do
    ble_meta = Chromoid.Devices.Presence.list("devices:#{device.id}")

    embed =
      %Nostrum.Struct.Embed{}
      |> put_color(0x00FF00)
      |> put_title("Device Status Report")
      |> put_author(
        device.serial,
        device_url(@endpoint, :show, device),
        device.avatar_url
      )
      |> put_timestamp(meta.online_at)

    embed =
      Enum.reduce(ble_meta, embed, fn
        {addr, %{serial: _serial}}, embed ->
          embed
          |> put_field(
            "**#{format_address(addr)}**",
            "`-color #{format_address(addr)} #{Color.random_color()}`"
          )
      end)

    {:create_message!, [message.channel_id, [embed: embed]]}
  end

  def device_join_action(channel_id, device, meta) do
    embed =
      %Nostrum.Struct.Embed{}
      |> put_color(0x00FF00)
      |> put_title("Device Status Report")
      |> put_author(
        device.serial,
        device_url(@endpoint, :show, device),
        device.avatar_url
      )
      |> put_description("has come online")
      |> put_timestamp(meta.online_at)

    {:create_message!, [channel_id || 755_850_677_548_220_468, [embed: embed]]}
  end

  def device_leave_action(channel_id, device, _meta) do
    embed =
      %Nostrum.Struct.Embed{}
      |> put_color(0xFF0000)
      |> put_title("Device Status Report")
      |> put_author(
        device.serial,
        device_url(@endpoint, :show, device),
        device.avatar_url
      )
      |> put_description("has gone offline")
      |> put_timestamp(DateTime.utc_now() |> to_string())

    {:create_message!, [channel_id || 755_850_677_548_220_468, [embed: embed]]}
  end

  def error_action(message, error) do
    {:create_message!, [message.channel_id, error]}
  end

  def ble_device_join_action(channel_id, device, address, meta) do
    embed = embed_for_ble_connection(device, address, meta)
    {:create_message!, [channel_id || 755_850_677_548_220_468, [embed: embed]]}
  end

  def embed_for_ble_connection(device, address, %{error: message} = meta)
      when is_binary(message) do
    %Nostrum.Struct.Embed{}
    |> put_color(0xFF0000)
    |> put_title("BLE Connection Update #{format_address(address)}")
    |> put_author(
      device.serial,
      device_url(@endpoint, :show, device),
      device.avatar_url
    )
    |> put_description(message)
    |> put_timestamp(meta.online_at)
  end

  def embed_for_ble_connection(device, address, meta) do
    %Nostrum.Struct.Embed{}
    |> put_color(meta.color)
    |> put_title("BLE Connection Update #{format_address(address)}")
    |> put_author(
      device.serial,
      device_url(@endpoint, :show, device),
      device.avatar_url
    )
    # |> put_description("Connected to BLE Device: #{format_address(address)}")
    |> put_timestamp(meta.online_at)
  end
end