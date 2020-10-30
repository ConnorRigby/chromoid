defmodule ChromoidDiscord.Guild.LuaConsumer do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.{EventDispatcher, ChannelCache}
  alias ChromoidDiscord.Guild.LuaConsumer.Runtime

  defmodule Exit do
    defstruct [:reason, :timestamp]
  end

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  def index_scripts(guild) do
    import Ecto.Query

    scripts =
      Chromoid.Repo.all(
        from s in Chromoid.Lua.Script,
          where: s.active == true and s.subsystem == "discord" and is_nil(s.deleted_at)
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

  def deactivate_script(guild, script) do
    GenServer.call(via(guild, __MODULE__), {:deactivate, script})
  end

  def subcribe_script(guild, id, pid) do
    GenServer.call(via(guild, __MODULE__), {:subcribe_script, id, pid})
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    Process.flag(:trap_exit, true)

    state = %{
      guild: guild,
      current_user: current_user,
      config: config,
      pool: %{},
      exits: %{},
      subscribers: []
    }

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

    state = log_exit(state, id, reason)

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

    state = log_exit(state, id, reason)

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

  def handle_call({:deactivate, script}, _from, state) do
    {reply, state} = stop_runtime(state, script)
    {:reply, reply, [], state}
  end

  def handle_call({:subcribe_script, id, pid}, _from, state) do
    subscribers = [{id, pid} | state.subscribers]
    {:reply, :ok, [], %{state | subscribers: subscribers}}
  end

  defp start_runtime(state, script) do
    case Runtime.start_link(state.guild, state.current_user, script, self()) do
      {:ok, pid} ->
        monitor = Process.monitor(pid)
        pool = Map.put(state.pool, script.id, {pid, monitor})
        {{:ok, pid}, %{state | pool: pool}}

      {:error, {:already_started, pid}} ->
        Logger.warn("Restarting script: #{inspect(script.id)}")
        {{^pid, monitor}, pool} = Map.pop!(state.pool, script.id)
        Process.demonitor(monitor, [:flush, :info])
        GenServer.stop(pid, :normal)
        start_runtime(%{state | pool: pool}, script)

      error ->
        Logger.error("Failed to load script: #{inspect(script.id)}: #{inspect(error)}")
        {error, state}
    end
  end

  def stop_runtime(state, script) do
    case state.pool[script.id] do
      {pid, monitor} ->
        Process.demonitor(monitor, [:flush, :info])
        reply = GenServer.stop(pid, :normal)
        {reply, %{state | pool: Map.delete(state.pool, script.id)}}

      nil ->
        {nil, state}
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

  defp log_exit(state, id, reason) do
    # IO.inspect(reason, limit: :infinity)
    exit_instance = %Exit{reason: reason, timestamp: DateTime.utc_now()}
    exits = Map.put_new(state.exits, id, [])
    exits = %{exits | id => [exit_instance | state.exits[id]]}

    for {subscription_id, pid} <- state.subscribers do
      if subscription_id == id do
        data = [
          "\r\n",
          IO.ANSI.red(),
          format_reason(reason),
          IO.ANSI.normal(),
          "\r\n"
        ]

        send(pid, {:tty_data, IO.iodata_to_binary(data)})
      end
    end

    %{state | exits: exits}
  end

  defp format_reason({{:lua_error, error, lua}, _elixir_stacktrace}) do
    stacktrace = :new_luerl.get_stacktrace(lua)

    formatted =
      Enum.map(stacktrace, fn {name, _, meta} ->
        "#{meta[:file]}:#{meta[:line]}: in function: #{name}"
      end)

    """
    [Lua Error]
    \r#{inspect(error)}

    \rStack traceback:
    \r#{Enum.join(formatted, "\r\n  ")}
    """
  end

  defp format_reason(reason) do
    inspect(reason, limit: :infinity, pretty: true)
  end
end
