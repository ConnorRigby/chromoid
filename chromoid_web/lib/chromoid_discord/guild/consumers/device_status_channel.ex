defmodule ChromoidDiscord.Guild.DeviceStatusChannel do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  import ChromoidWeb.Router.Helpers, only: [device_url: 3]
  alias ChromoidDiscord.Guild.EventDispatcher
  alias Chromoid.Repo

  alias Phoenix.Socket.Broadcast

  import Nostrum.Struct.Embed

  @endpoint ChromoidWeb.Endpoint

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    @endpoint.subscribe("devices")

    {:producer_consumer, %{guild: guild, current_user: current_user, config: config},
     subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_events(events, _from, %{current_user: %{id: current_user_id}} = state) do
    {actions, state} =
      Enum.reduce(events, {[], state}, fn
        # Ignore messages from self
        {:MESSAGE_CREATE, %{author: %{id: author_id}}}, {actions, state}
        when author_id == current_user_id ->
          {actions, state}

        {:MESSAGE_CREATE, message}, {actions, state} ->
          handle_message(message, {actions, state})

        _, {actions, state} ->
          {actions, state}
      end)

    {:noreply, actions, state}
  end

  @impl GenStage
  def handle_info(
        %Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: leaves},
          topic: "devices"
        },
        state
      ) do
    join_events =
      for {id, meta} <- joins do
        @endpoint.subscribe("devices:#{id}")
        device = Repo.get!(Chromoid.Devices.Device, id)

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

        {:create_message!, [state.config.device_status_channel_id, [embed: embed]]}
      end

    leave_events =
      for {id, _meta} <- leaves do
        device = Repo.get!(Chromoid.Devices.Device, id)
        @endpoint.unsubscribe("devices:#{id}")

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

        {:create_message!, [state.config.device_status_channel_id, [embed: embed]]}
      end

    {:noreply, join_events ++ leave_events, state}
  end

  def handle_info(
        %Broadcast{
          event: "presence_diff",
          payload: %{joins: joins, leaves: _leaves},
          topic: "devices:" <> device_id
        },
        state
      ) do
    device = Repo.get!(Chromoid.Devices.Device, device_id)

    join_events =
      for {address, meta} <- joins do
        embed = embed_for_ble_connection(device, address, meta)
        {:create_message!, [state.config.device_status_channel_id, [embed: embed]]}
      end

    {:noreply, join_events, state}
  end

  def handle_info(%Broadcast{}, state) do
    {:noreply, [], state}
  end

  @device_info_regex ~r/-device info (?<serial>[a-z_\-]+)/
  @device_photo_regex ~r/-device photo (?<serial>[a-z_\-]+)/

  @color_hex_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>\#[[:xdigit:]]{6})/
  @color_friendly_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>(white)|(silver)|(gray)|(black)|(red)|(maroon)|(yellow)|(olive)|(lime)|(green)|(aqua)|(teal)|(blue)|(navy)|(fuchsia)|(purple))/

  def handle_message(message, {actions, state}) do
    cond do
      String.contains?(message.content, "-device list") ->
        {actions ++ device_list_action(message), state}

      String.match?(message.content, @device_photo_regex) ->
        handle_device_photo(
          message,
          Regex.named_captures(@device_photo_regex, message.content),
          {actions, state}
        )

      String.match?(message.content, @device_info_regex) ->
        handle_device_info(
          message,
          Regex.named_captures(@device_info_regex, message.content),
          {actions, state}
        )

      String.match?(message.content, @color_hex_regex) ->
        handle_color(
          message,
          Regex.named_captures(@color_hex_regex, message.content),
          {actions, state}
        )

      String.match?(message.content, @color_friendly_regex) ->
        handle_color(
          message,
          Regex.named_captures(@color_friendly_regex, message.content),
          {actions, state}
        )

      String.match?(message.content, ~r/-color(.)+/) ->
        error_message = """
        Could not decode color arguments.
        `-color` `[address]` `color`
        See `-help color` for more info

        Examples:
        `-color A4:C1:38:9D:1E:AD red`
        `-color A4:C1:38:9D:1E:AD green`
        `-color A4:C1:38:9D:1E:AD blue`
        `-color A4:C1:38:9D:1E:AD #ff0000`
        `-color A4:C1:38:9D:1E:AD #00ff00`
        `-color A4:C1:38:9D:1E:AD #0000ff`
        """

        {actions ++ [error_action(message, error_message)], state}

      true ->
        {actions, state}
    end
  end

  def handle_device_photo(message, %{"serial" => serial}, {actions, state}) do
    case Repo.get_by(Chromoid.Devices.Device, serial: serial) do
      nil ->
        {actions ++
           [error_action(message, "Could not find device by that serial number: `#{serial}`")],
         state}

      device ->
        {:ok, data} = Chromoid.Devices.Photo.request_photo(device.id)

        action =
          {:create_message!,
           [message.channel_id, [file: %{name: data["name"], body: data["content"]}]]}

        {actions ++ [action], state}
    end
  end

  def handle_device_info(message, %{"serial" => serial}, {actions, state}) do
    case Repo.get_by(Chromoid.Devices.Device, serial: serial) do
      nil ->
        {actions ++
           [error_action(message, "Could not find device by that serial number: `#{serial}`")],
         state}

      device ->
        meta = Chromoid.Devices.Presence.list("devices")["#{device.id}"]
        {actions ++ [device_info_action(message, device, meta)], state}
    end
  end

  def handle_color(
        message,
        %{"address" => address_with_colons, "color" => color_arg},
        {actions, state}
      ) do
    address = String.replace(address_with_colons, ":", "") |> String.to_integer(16) |> to_string()
    color = decode_color_arg(color_arg)

    device_id = Chromoid.Devices.Presence.device_id_for_address(address)

    if device_id do
      device = Repo.get!(Chromoid.Devices.Device, device_id)

      Logger.info(
        "Sending color change command: #{format_address(address)} #{inspect(color, base: :hex)}"
      )

      meta = Chromoid.Devices.Color.set_color(address, color)
      embed = embed_for_ble_connection(device, address, meta)
      action = {:create_message!, [message.channel_id, [embed: embed]]}
      {actions ++ [action], state}
    else
      error_message = "couldn't find the device that #{format_address(address)} is attached to"
      error = error_action(message, error_message)
      {actions ++ [error], state}
    end
  end

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
            "`-color #{format_address(addr)} #{random_color()}`"
          )
      end)

    {:create_message!, [message.channel_id, [embed: embed]]}
  end

  def error_action(message, error) do
    {:create_message!, [message.channel_id, error]}
  end

  defp embed_for_ble_connection(device, address, %{error: message} = meta)
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

  defp embed_for_ble_connection(device, address, meta) do
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

  defp format_address(address) do
    <<a, b, c, d, e, f>> = <<String.to_integer(address)::48>>
    :io_lib.format('~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B', [a, b, c, d, e, f])
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

  defp random_color() do
    Enum.random([
      "white",
      "silver",
      "gray",
      "black",
      "red",
      "maroon",
      "yellow",
      "olive",
      "lime",
      "green",
      "aqua",
      "teal",
      "blue",
      "navy",
      "fuchsia",
      "purple"
    ])
  end
end
