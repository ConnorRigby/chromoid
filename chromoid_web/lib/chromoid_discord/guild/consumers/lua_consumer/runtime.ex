defmodule ChromoidDiscord.Guild.LuaConsumer.Runtime do
  use GenServer
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  require Logger

  def start_link(guild, current_user, script, parent) do
    # atom leak
    name = via(guild, Module.concat([__MODULE__, script.path]))
    GenServer.start_link(__MODULE__, [guild, current_user, script, parent], name: name)
  end

  def message_create(pid, message, channel) do
    GenServer.call(pid, {:message_create, message, channel})
  catch
    error, reason ->
      {error, reason}
  end

  def typing_start(pid, user_id, channel_id, timestamp) do
    GenServer.call(pid, {:typing_start, user_id, channel_id, timestamp})
  catch
    error, reason ->
      {error, reason}
  end

  def channel_create(pid, channel) do
    GenServer.call(pid, {:channel_create, channel})
  catch
    error, reason ->
      {error, reason}
  end

  def channel_update(pid, channel) do
    GenServer.call(pid, {:channel_update, channel})
  catch
    error, reason ->
      {error, reason}
  end

  def channel_delete(pid, channel) do
    GenServer.call(pid, {:channel_delete, channel})
  catch
    error, reason ->
      {error, reason}
  end

  @impl GenServer
  def init([guild, current_user, script, parent]) do
    lua = Chromoid.Lua.init(guild, current_user, script)
    path = to_charlist(Path.expand(script.path))

    case :luerl.dofile(path, lua) do
      {[tref], lua} ->
        {_, lua} = Chromoid.Lua.Discord.Client.ready(tref, lua)
        {:ok, %{script: script, parent: parent, client: tref, lua: lua, tref: tref}}

      {error, _lua} ->
        Logger.error("Failed to start lua script: #{inspect(script.id)}")
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_info({:client, tref}, %{client: tref} = state) do
    {_, lua} = Chromoid.Lua.Discord.Client.ready(tref, state.lua)
    {:noreply, %{state | client: tref, lua: lua}}
  end

  def handle_info({:action, action}, state) do
    send(state.parent, {:action, action})
    {:noreply, state}
  end

  def handle_info({:log, id, level, message}, state) do
    send(state.parent, {:log, id, level, message})
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:message_create, message, channel}, _from, state) do
    {return, lua} =
      Chromoid.Lua.Discord.Client.message_create(state.client, message, channel, state.lua)

    {:reply, return, %{state | lua: lua}}
  end

  def handle_call({:typing_start, user_id, channel_id, timestamp}, _from, state) do
    {return, lua} =
      Chromoid.Lua.Discord.Client.typing_start(
        state.client,
        user_id,
        channel_id,
        timestamp,
        state.lua
      )

    {:reply, return, %{state | lua: lua}}
  end

  def handle_call({:channel_create, channel}, _from, state) do
    {return, lua} = Chromoid.Lua.Discord.Client.channel_create(state.client, channel, state.lua)
    {:reply, return, %{state | lua: lua}}
  end

  def handle_call({:channel_update, channel}, _from, state) do
    {return, lua} = Chromoid.Lua.Discord.Client.channel_update(state.client, channel, state.lua)
    {:reply, return, %{state | lua: lua}}
  end

  def handle_call({:channel_delete, channel}, _from, state) do
    {return, lua} = Chromoid.Lua.Discord.Client.channel_delete(state.client, channel, state.lua)
    {:reply, return, %{state | lua: lua}}
  end
end
