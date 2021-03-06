defmodule Chromoid.Lua.Discord.Client do
  require Logger
  use Chromoid.Lua.Class, :new

  alias Chromoid.Lua.Discord.{
    Message,
    Channel
  }

  defstruct []

  alloc properties: [
          on: &on/2,
          user: Chromoid.Lua.Discord.User
        ]

  # def alloc(user, state) do
  #   {client, state} = :luerl_heap.alloc_table(table(user), state)
  #   state = :luerl_emul.set_global_key(["_client"], client, state)
  #   {{:userdata, pid}, state} = :luerl.get_table(["_self"], state)
  #   send(pid, {:client, client})

  #   {client, state}
  # end

  # def table(user) do
  #   [
  #     {"on", erl_func(code: &on/2)},
  #     {"user", user}
  #   ]
  # end

  defimpl Chromoid.Lua.Object do
    def to_lua(_data, properties) do
      [
        {"user", properties[:user]},
        {"on", properties[:on]}
      ]
    end
  end

  def ready(client, state) do
    case :luerl_emul.get_table_key(client, "ready", state) do
      {nil, state} ->
        Logger.error("on_ready function not defined by script")
        {[], state}

      {func, state} ->
        :luerl_emul.call(func, [], state)
    end
  end

  def message_create(client, message, channel, state) do
    IO.inspect(client, label: "???")

    case :luerl_emul.get_table_key(client, "messageCreate", state) do
      {nil, state} ->
        Logger.error("messageCreate function not defined by script")
        {[], state}

      {func, state} ->
        {channel, state} = Channel.alloc(channel, %{}, state)
        {message, state} = Message.alloc(message, %{channel: channel}, state)
        :luerl_emul.call(func, [message], state)
    end
  end

  def typing_start(client, user_id, channel_id, timestamp, state) do
    case :luerl_emul.get_table_key(client, "typingStart", state) do
      {nil, state} ->
        Logger.error("typingStart function not defined by script")
        {[], state}

      {func, state} ->
        :luerl_emul.call(func, [user_id, channel_id, timestamp], state)
    end
  end

  def channel_create(client, channel, state) do
    case :luerl_emul.get_table_key(client, "channelCreate", state) do
      {nil, state} ->
        Logger.error("channelCreate function not defined by script")
        {[], state}

      {func, state} ->
        {channel, state} = Channel.alloc(channel, %{}, state)
        :luerl_emul.call(func, [channel], state)
    end
  end

  def channel_update(client, channel, state) do
    case :luerl_emul.get_table_key(client, "channelUpdate", state) do
      {nil, state} ->
        Logger.error("channelUpdate function not defined by script")
        {[], state}

      {func, state} ->
        {channel, state} = Channel.alloc(channel, %{}, state)
        :luerl_emul.call(func, [channel], state)
    end
  end

  def channel_delete(client, channel, state) do
    case :luerl_emul.get_table_key(client, "channelDelete", state) do
      {nil, state} ->
        Logger.error("channelDelete function not defined by script")
        {[], state}

      {func, state} ->
        {channel, state} = Channel.alloc(channel, %{}, state)
        :luerl_emul.call(func, [channel], state)
    end
  end

  def on([client, event, func], state) do
    IO.puts("client:on #{inspect(client)}")
    {{:userdata, script}, state} = :luerl.get_table(["_script"], state)
    state = :luerl_emul.set_table_key(client, event, func, state)
    {lua_func, state} = :luerl_heap.get_funcdef(func, state)
    anno = lua_func(lua_func, :anno)
    updated_anno = :luerl_anno.set(:name, "client:on('#{event}')", anno)
    updated_anno = :luerl_anno.set(:file, script.filename, updated_anno)
    updated_lua_func = lua_func(lua_func, anno: updated_anno)
    state = :luerl_heap.set_funcdef(func, updated_lua_func, state)
    {[client], state}
  end
end
