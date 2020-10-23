defmodule ChromoidDiscord.Guild.LuaConsumer.Runtime do
  use GenServer
  # import ChromoidDiscord.Guild.Registry, only: [via: 2]

  def start_link(guild, current_user, script, parent) do
    GenServer.start_link(__MODULE__, [guild, current_user, script, parent])
  end

  def message_create(pid, message, channel) do
    GenServer.call(pid, {:message_create, message, channel})
  end

  @impl GenServer
  def init([guild, current_user, script, parent]) do
    lua = Chromoid.Lua.init(guild, current_user)
    path = to_charlist(Path.expand(script.path))
    {_, lua} = :luerl.dofile(path, lua)
    {:ok, %{script: script, parent: parent, client: nil, lua: lua}}
  end

  @impl GenServer
  def handle_info({:client, tref}, state) do
    {_, lua} = Chromoid.Lua.Discord.Client.ready(tref, state.lua)
    {:noreply, %{state | client: tref, lua: lua}}
  end

  def handle_info({:action, action}, state) do
    send(state.parent, {:action, action})
  end

  @impl GenServer
  def handle_call({:message_create, message, channel}, _from, state) do
    {_return, lua} =
      Chromoid.Lua.Discord.Client.message_create(state.client, message, channel, state.lua)

    {:reply, %{state | lua: lua}}
  end
end
