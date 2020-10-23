defmodule ChromoidDiscord.Guild.LuaConsumer do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.{EventDispatcher, ChannelCache}
  alias ChromoidDiscord.Guild.LuaConsumer.Runtime

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  def pid(guild) do
    GenServer.whereis(via(guild, __MODULE__))
  end

  def activate_script(guild, script) do
    GenServer.call(via(guild, __MODULE__), {:activate, script})
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    state = %{guild: guild, current_user: current_user, config: config, pool: %{}}
    {:producer_consumer, state, subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_info({:action, action}, state) do
    Logger.info("Inbound action from lua script: #{inspect(action)}")
    {:noreply, [action], state}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    {actions, pool} = Enum.reduce(events, {[], state.pool}, &handle_event/2)
    {:noreply, actions, %{state | pool: pool}}
  end

  @impl GenStage
  def handle_call({:activate, script}, _from, state) do
    {:ok, pid} = Runtime.start_link(state.guild, state.current_user, script, self())
    Process.monitor(pid)
    pool = Map.put(state.pool, script.id, pid)
    {:reply, {:ok, pid}, [], %{state | pool: pool}}
  end

  def handle_event({:MESSAGE_CREATE, message}, {acc, pool}) do
    channel = ChannelCache.get_channel!(message.guild_id, message.channel_id)

    for {_, pid} <- pool do
      Runtime.message_create(pid, message, channel)
    end

    {acc, pool}
  end

  def handle_event(event, {actions, pool}) do
    Logger.error("Unknown event in Lua handler: #{inspect(event)}")
    {actions, pool}
  end
end
