defmodule ChromoidDiscord.Guild.DeviceStatusChannel do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.EventDispatcher
  alias Chromoid.Repo
  import ChromoidDiscord.Guild.DeviceStatusChannel.Actions
  import Chromoid.Devices.Ble.Utils

  alias Phoenix.Socket.Broadcast

  @endpoint ChromoidWeb.Endpoint

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    @endpoint.subscribe("devices")

    state = %{
      guild: guild,
      current_user: current_user,
      config: config
    }

    {:producer_consumer, state, subscribe_to: [via(guild, EventDispatcher)]}
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

        if leaves[id] do
          # update, not join
          :noop
        else
          device_join_action(state.config.device_status_channel_id, device, meta)
        end
      end

    leave_events =
      for {id, meta} <- leaves do
        device = Repo.get!(Chromoid.Devices.Device, id)
        @endpoint.unsubscribe("devices:#{id}")

        if joins[id] do
          # update, not leave
          :noop
        else
          device_leave_action(state.config.device_status_channel_id, device, meta)
        end
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
        ble_device_join_action(state.config.device_status_channel_id, device, address, meta)
      end

    {:noreply, join_events, state}
  end

  def handle_info(
        %Broadcast{
          event: "progress_report",
          payload: %{storage: storage, path: path, progress: progress},
          topic: "devices:" <> device_id
        },
        state
      ) do
    Logger.info("Processing progress report for discord")
    device = Repo.get!(Chromoid.Devices.Device, device_id)
    channel_id = state.config.device_status_channel_id
    progress_report_action = progress_report_action(channel_id, device, storage, path, progress)
    {:noreply, [progress_report_action], state}

    case Chromoid.Devices.Photo.request_photo(device) do
      {:ok, photo_response} ->
        photo_action = photo_action(channel_id, photo_response)
        {:noreply, [progress_report_action, photo_action], state}

      _error ->
        {:noreply, [progress_report_action], state}
    end
  end

  def handle_info(%Broadcast{} = unknown, state) do
    Logger.error("Unknown event: #{inspect(unknown)}")
    {:noreply, [], state}
  end

  @device_list_regex ~r/-device(?:\s{1,})list/
  @device_info_regex ~r/-device(?:\s{1,})info(?:\s{1,})(?<serial>[a-z_0-9\-]+)/
  @device_photo_regex ~r/-device(?:\s{1,})photo(?:\s{1,})(?<serial>[a-z_0-9\-]+)/
  @device_nick_regex ~r/-device(?:\s{1,})nick(?:\s{1,})(?<serial>[a-z_0-9\-]+)(?:\s{1,})(?<nickname>.+)/
  @color_hex_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>\#[[:xdigit:]]{6})/
  @color_friendly_regex ~r/-color(?:\s{1,})(?<address>(?:[[:xdigit:]]{2}\:?){6})(?:\s{1,})(?<color>(white)|(silver)|(gray)|(black)|(red)|(maroon)|(yellow)|(olive)|(lime)|(green)|(aqua)|(teal)|(blue)|(navy)|(fuchsia)|(purple))/

  def handle_message(message, {actions, state}) do
    cond do
      String.match?(message.content, @device_list_regex) ->
        handle_device_list(
          message,
          Regex.named_captures(@device_list_regex, message.content),
          {actions, state}
        )

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

      String.match?(message.content, @device_nick_regex) ->
        handle_device_nick(
          message,
          Regex.named_captures(@device_nick_regex, message.content),
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

  def handle_device_list(message, _, {actions, state}) do
    {actions ++ device_list_action(message), state}
  end

  def handle_device_photo(message, %{"serial" => serial}, {actions, state}) do
    case find_device(state.config, serial) do
      nil ->
        {actions ++
           [error_action(message, "Could not find device by that serial number: `#{serial}`")],
         state}

      device ->
        {:ok, data} = Chromoid.Devices.Photo.request_photo(device)

        action =
          {:create_message!,
           [message.channel_id, [file: %{name: data["name"], body: data["content"]}]]}

        {actions ++ [action], state}
    end
  end

  def handle_device_info(message, %{"serial" => serial}, {actions, state}) do
    case find_device(state.config, serial) do
      nil ->
        {actions ++
           [error_action(message, "Could not find device by that serial number: `#{serial}`")],
         state}

      device ->
        meta = Chromoid.Devices.Presence.list("devices")["#{device.id}"]
        {actions ++ [device_info_action(message, device, meta)], state}
    end
  end

  def handle_device_nick(message, %{"nickname" => nickname, "serial" => serial}, {actions, state}) do
    case find_device(state.config, serial) do
      nil ->
        {actions ++
           [error_action(message, "Could not find device by that serial number: `#{serial}`")],
         state}

      device ->
        case Chromoid.Devices.set_nickname(state.config, device, nickname) do
          {:error, changeset} ->
            {actions ++
               [error_action(message, "Failed to set nickname: #{inspect(changeset.errors)}")],
             state}

          _ ->
            handle_device_info(message, %{"serial" => serial}, {actions, state})
        end
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

  def find_device(guild_config, serial_or_nickname) do
    Chromoid.Devices.find_device_by_nickname(guild_config, serial_or_nickname) ||
      Repo.get_by(Chromoid.Devices.Device, serial: serial_or_nickname)
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
