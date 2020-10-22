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

  def pid(guild) do
    GenServer.whereis(via(guild, __MODULE__))
  end

  def dofile(guild, filename) do
    GenStage.call(via(guild, __MODULE__), {:dofile, filename})
  end

  def evalfile(guild, filename) do
    GenStage.call(via(guild, __MODULE__), {:evalfile, filename})
  end

  def loadfile(guild, filename) do
    GenStage.call(via(guild, __MODULE__), {:loadfile, filename})
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    state = %{guild: guild, current_user: current_user, config: config, lua: nil, client: nil}
    {:producer_consumer, state, subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_info({:client, tref}, state) do
    {_, lua} = Chromoid.Lua.Discord.Client.ready(tref, state.lua)
    {:noreply, [], %{state | client: tref, lua: lua}}
  end

  def handle_info({:action, action}, state) do
    {:noreply, [action], state}
  end

  @impl GenStage
  def handle_call({:dofile, filename}, _from, state) do
    lua = Chromoid.Lua.init(state.guild, state.current_user)
    {return, lua} = :luerl.dofile(filename, lua)
    {:reply, return, [], %{state | lua: lua}}
  end

  def handle_call({:evalfile, filename}, _from, state) do
    lua = Chromoid.Lua.init(state.guild, state.current_user)
    return = :luerl.evalfile(filename, lua)
    {:reply, return, [], %{state | lua: lua}}
  end

  def handle_call({:loadfile, filename}, _from, state) do
    lua = Chromoid.Lua.init(state.guild, state.current_user)
    return = :luerl.loadfile(filename, lua)
    {:reply, return, [], %{state | lua: lua}}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    {actions, lua} = Enum.reduce(events, {[], state.lua}, &handle_event(state.client, &1, &2))
    {:noreply, actions, %{state | lua: lua}}
  end

  def handle_event(client, {:MESSAGE_CREATE, message}, {acc, lua}) do
    channel = ChannelCache.get_channel!(message.guild_id, message.channel_id)
    {_return, lua} = Chromoid.Lua.Discord.Client.message_create(client, message, channel, lua)
    {acc, lua}
  end

  def handle_event(_client, event, {actions, lua}) do
    Logger.error("Unknown event in Lua handler: #{inspect(event)}")
    {actions, lua}
  end
end
