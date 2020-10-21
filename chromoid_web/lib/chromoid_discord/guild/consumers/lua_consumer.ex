defmodule ChromoidDiscord.Guild.LuaConsumer do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.{EventDispatcher, ChannelCache}

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    lua = Chromoid.Lua.init(guild, current_user)

    {:producer_consumer,
     %{guild: guild, current_user: current_user, config: config, lua: lua, client: nil},
     subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_info({:client, tref}, state) do
    {_, lua} = Chromoid.Lua.Discord.Client.ready(tref, state.lua)
    {:noreply, [], %{state | client: tref, lua: lua}}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    lua =
      Enum.reduce(events, state.lua, fn
        {:MESSAGE_CREATE, message}, lua ->
          channel = ChannelCache.get_channel!(state.guild, message.channel_id)

          {_, lua} =
            Chromoid.Lua.Discord.Client.message_create(state.client, message, channel, lua)

          lua
      end)

    {:noreply, [], %{state | lua: lua}}
  end
end
