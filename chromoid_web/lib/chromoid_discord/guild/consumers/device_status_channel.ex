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
          |> put_timestamp(DateTime.utc_now())

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
        embed =
          %Nostrum.Struct.Embed{}
          |> put_color(0x00FF00)
          |> put_title("New BLE Connection")
          |> put_author(
            device.serial,
            device_url(@endpoint, :show, device),
            device.avatar_url
          )
          |> put_description("Connected to BLE Device: #{format_address(address)}")
          |> put_timestamp(meta.online_at)

        {:create_message!, [state.config.device_status_channel_id, [embed: embed]]}
      end

    {:noreply, join_events, state}
  end

  def handle_info(%Broadcast{}, state) do
    {:noreply, [], state}
  end

  # ChromoidWeb.Endpoint.broadcast("devices:1", "set_color", %{})

  defp format_address(address) do
    <<a, b, c, d, e, f>> = <<String.to_integer(address)::48>>
    :io_lib.format('~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B:~2.16.0B', [a, b, c, d, e, f])
  end

  @device_info_regex ~r/-device info (?<serial>[a-z_\-]+)/
  @color_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>\#[[:xdigit:]]{6})/

  def handle_message(message, {actions, state}) do
    cond do
      String.contains?(message.content, "-device list") ->
        {actions ++ device_list_action(message), state}

      String.match?(message.content, @device_info_regex) ->
        %{"serial" => serial} = Regex.named_captures(@device_info_regex, message.content)

        case Repo.get_by(Chromoid.Devices.Device, serial: serial) do
          nil ->
            {actions ++
               [error_action(message, "Could not find device by that serial number: `#{serial}`")],
             state}

          device ->
            meta = Chromoid.Devices.Presence.list("devices")["#{device.id}"]
            {actions ++ [device_info_action(message, device, meta)], state}
        end

      String.match?(message.content, @color_regex) ->
        handle_color(
          message,
          Regex.named_captures(@color_regex, message.content),
          {actions, state}
        )

      true ->
        {actions, state}
    end
  end

  def handle_color(
        message,
        %{"address" => address_with_colons, "color" => "#" <> hex_str},
        {actions, state}
      ) do
    address = String.replace(address_with_colons, ":", "") |> String.to_integer(16) |> to_string()
    color = String.to_integer(hex_str, 16)

    device_id =
      for {id, _meta} <- Chromoid.Devices.Presence.list("devices") do
        for {addr, _} <- Chromoid.Devices.Presence.list("devices:#{id}") do
          {id, addr}
        end
      end
      |> List.flatten()
      |> Enum.find_value(fn
        {device_id, ^address} -> device_id
        _ -> false
      end)

    if device_id do
      @endpoint.broadcast("devices:#{device_id}:#{address}", "set_color", %{color: color})

      embed =
        %Nostrum.Struct.Embed{}
        |> put_title("**#{format_address(address)}**")
        |> put_color(color)
        |> put_description("Color set successfully")

      {actions ++ [{:create_message!, [message.channel_id, [embed: embed]]}], state}
    else
      {actions ++
         [
           {:create_message!,
            [
              message.channel_id,
              "couldn't find the device that #{format_address(address)} is attached to"
            ]}
         ], state}
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
          |> put_field("**#{format_address(addr)}**", "-color #{format_address(addr)} #ff00ff")
      end)

    {:create_message!, [message.channel_id, [embed: embed]]}
  end

  def error_action(message, error) do
    {:create_message!, [message.channel_id, error]}
  end
end
