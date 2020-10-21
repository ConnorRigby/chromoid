defmodule Chromoid.Lua.Discord.Channel do
  use Chromoid.Lua.Class
  alias Nostrum.Struct.Channel

  def alloc(%Channel{} = channel, state) do
    :luerl_heap.alloc_table(table(channel), state)
  end

  def table(%Channel{id: id}) do
    [
      {"send", erl_func(code: &channel_send/2)},
      {"id", id}
    ]
  end

  def channel_send([self, content], state) do
    {channel_id, state} = :luerl_emul.get_table_key(self, "id", state)
    IO.inspect(content, label: to_string(channel_id))
    # BakedBot.Discord.api().create_message!(channel_id, content)
    {[], state}
  end
end
