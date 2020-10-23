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

  def index_scripts(guild) do
    import Ecto.Query

    scripts =
      Chromoid.Repo.all(
        from s in Chromoid.Lua.Script, where: s.active == true and s.subsystem == "discord"
      )

    for script <- scripts do
      Logger.info("Loading script: #{inspect(script)}")
      activate_script(guild, script)
    end
  end

  def pid(guild) do
    GenServer.whereis(via(guild, __MODULE__))
  end

  def activate_script(guild, script) do
    GenServer.call(via(guild, __MODULE__), {:activate, script})
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    Process.flag(:trap_exit, true)
    state = %{guild: guild, current_user: current_user, config: config, pool: %{}}
    {:producer_consumer, state, subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_info({:action, action}, state) do
    Logger.info("Inbound action from lua script: #{inspect(action)}")
    {:noreply, [action], state}
  end

  def handle_info({:EXIT, pid, :normal}, state) do
    id =
      Enum.find_value(state.pool, fn
        {id, {^pid, monitor}} ->
          Process.demonitor(monitor)
          id

        {_id, {_pid, _monitor}} ->
          false
      end)

    pool = Map.delete(state.pool, id)
    state = %{state | pool: pool}
    {:noreply, [], state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    id =
      Enum.find_value(state.pool, fn
        {id, {^pid, monitor}} ->
          Process.demonitor(monitor)
          Logger.error("Script #{inspect(id)} crashed: #{inspect(reason)}")
          id

        {_id, {_pid, _monitor}} ->
          false
      end)

    pool = Map.delete(state.pool, id)
    state = %{state | pool: pool}

    if id do
      Logger.info("Restarting script: #{inspect(id)}")
      script = Chromoid.Lua.ScriptStorage.load_script(id)
      {_, state} = start_runtime(state, script)
      {:noreply, [], state}
    else
      Logger.warn("Could not fetch script. Not restarting")
      {:noreply, [], state}
    end
  end

  def handle_info({:DOWN, monitor, :process, pid, reason}, state) do
    id =
      Enum.find_value(state.pool, fn
        {id, {^pid, ^monitor}} ->
          Logger.error("Script #{inspect(id)} crashed: #{inspect(reason)}")
          id

        {_id, {_pid, _monitor}} ->
          false
      end)

    pool = Map.delete(state.pool, id)
    state = %{state | pool: pool}

    if id do
      Logger.info("Restarting script: #{inspect(id)}")
      script = Chromoid.Lua.ScriptStorage.load_script(id)
      {_, state} = start_runtime(state, script)
      {:noreply, [], state}
    else
      Logger.warn("Could not fetch script. Not restarting")
      {:noreply, [], state}
    end
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    {actions, pool} = Enum.reduce(events, {[], state.pool}, &handle_event/2)
    {:noreply, actions, %{state | pool: pool}}
  end

  @impl GenStage
  def handle_call({:activate, script}, _from, state) do
    {reply, state} = start_runtime(state, script)
    {:reply, reply, [], state}
  end

  defp start_runtime(state, script) do
    case Runtime.start_link(state.guild, state.current_user, script, self()) do
      {:ok, pid} ->
        monitor = Process.monitor(pid)
        pool = Map.put(state.pool, script.id, {pid, monitor})
        {{:ok, pid}, %{state | pool: pool}}

      {:error, {:already_started, pid}} ->
        Logger.warn("Restarting script: #{inspect(script)}")
        {{^pid, monitor}, pool} = Map.pop!(state.pool, script.id)
        Process.demonitor(monitor, [:flush, :info])
        GenServer.stop(pid, :normal)
        start_runtime(%{state | pool: pool}, script)

      error ->
        Logger.error("Failed to load script: #{inspect(script)}: #{inspect(error)}")
        {error, state}
    end
  end

  def handle_event({:MESSAGE_CREATE, message}, {acc, pool}) do
    channel = ChannelCache.get_channel!(message.guild_id, message.channel_id)

    for {_, {pid, _monitor}} <- pool do
      Runtime.message_create(pid, message, channel)
    end

    {acc, pool}
  end

  def handle_event(event, {actions, pool}) do
    Logger.error("Unknown event in Lua handler: #{inspect(event)}")
    {actions, pool}
  end
end
