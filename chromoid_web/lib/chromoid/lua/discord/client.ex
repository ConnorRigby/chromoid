defmodule Chromoid.Lua.Discord.Client do
  use Chromoid.Lua.Class

  alias Chromoid.Lua.Discord.{
    Message,
    Channel
  }

  def ready(client, state) do
    func = :luerl_emul.get_table_key(client, "_on_ready", state)
    :luerl_emul.call(func, [], state)
  end

  def message_create(client, message, channel, state) do
    func = :luerl_emul.get_table_key(client, "_on_messageCreate", state)
    {channel, state} = Channel.alloc(channel, state)
    {message, state} = Message.alloc(message, channel, state)
    :luerl_emul.call(func, [message], state)
  end

  def alloc(user, state) do
    :luerl_heap.alloc_table(table(user), state)
  end

  def table(user) do
    [
      {"on", erl_func(code: &on/2)},
      {"user", user}
    ]
  end

  def on([client, "ready", func], state) do
    {{:userdata, pid}, state} = :luerl.get_table(["_discord", "_self"], state)
    send(pid, {:client, client})
    state = :luerl_emul.set_table_key(client, "_on_ready", func, state)
    {[], state}
  end

  def on([client, "messageCreate", func], state) do
    state = :luerl_emul.set_table_key(client, "_on_messageCreate", func, state)
    {[], state}
  end

  def on(args, _state) do
    raise """
    Unknown Client args:
    #{inspect(args)}
    """
  end
end
