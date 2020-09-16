defmodule ChromoidDiscord.Guild.DeviceStatusChannel do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.EventDispatcher
  alias Chromoid.Repo

  alias Phoenix.Socket.Broadcast

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    ChromoidWeb.Endpoint.subscribe("devices")

    {:consumer, %{guild: guild, current_user: current_user, config: config},
     subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_events(events, _from, %{current_user: %{id: current_user_id}} = state) do
    state =
      Enum.reduce(events, state, fn
        _, state ->
          state
      end)

    {:noreply, [], state}
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
    for {id, meta} <- joins do
      device = Repo.get!(Chromoid.Devices.Device, id)
      message = "#{device.serial} has come online: #{inspect(meta)}"
      Nostrum.Api.create_message!(state.config.device_status_channel_id, message)
    end

    for {id, meta} <- leaves do
      device = Repo.get!(Chromoid.Devices.Device, id)
      message = "#{device.serial} has come gone offline: #{inspect(meta)}"
      Nostrum.Api.create_message!(state.config.device_status_channel_id, message)
    end

    {:noreply, [], state}
  end
end
