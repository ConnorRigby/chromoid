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

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    ChromoidWeb.Endpoint.subscribe("devices")

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
        device = Repo.get!(Chromoid.Devices.Device, id)

        embed =
          %Nostrum.Struct.Embed{}
          |> put_color(0x00FF00)
          |> put_title("Device Status Report")
          |> put_author(
            device.serial,
            device_url(ChromoidWeb.Endpoint, :show, device),
            device.avatar_url
          )
          |> put_description("has come online")
          |> put_timestamp(meta.online_at)

        {:create_message!, [state.config.device_status_channel_id, [embed: embed]]}
      end

    leave_events =
      for {id, _meta} <- leaves do
        device = Repo.get!(Chromoid.Devices.Device, id)

        embed =
          %Nostrum.Struct.Embed{}
          |> put_color(0xFF0000)
          |> put_title("Device Status Report")
          |> put_author(
            device.serial,
            device_url(ChromoidWeb.Endpoint, :show, device),
            device.avatar_url
          )
          |> put_description("has gone offline")
          |> put_timestamp(DateTime.utc_now())

        {:create_message!, [state.config.device_status_channel_id, [embed: embed]]}
      end

    {:noreply, join_events ++ leave_events, state}
  end

  @device_info_regex ~r/-device info (?<serial>[a-z_\-]+)/

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

      true ->
        {actions, state}
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
    embed =
      %Nostrum.Struct.Embed{}
      |> put_color(0x00FF00)
      |> put_title("Device Status Report")
      |> put_author(
        device.serial,
        device_url(ChromoidWeb.Endpoint, :show, device),
        device.avatar_url
      )
      |> put_timestamp(meta.online_at)

    {:create_message!, [message.channel_id, [embed: embed]]}
  end

  def error_action(message, error) do
    {:create_message!, [message.channel_id, error]}
  end
end
