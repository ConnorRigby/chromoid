defmodule Chromoid.Lua.Discord.Channel do
  use Chromoid.Lua.Class
  import Chromoid.Lua.Discord, only: [schedule_action: 2]
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
    schedule_action({:create_message!, [channel_id, content]}, state)
  end
end
