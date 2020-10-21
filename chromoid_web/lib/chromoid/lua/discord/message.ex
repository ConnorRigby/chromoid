defmodule Chromoid.Lua.Discord.Message do
  use Chromoid.Lua.Class
  alias Nostrum.Struct.Message

  def alloc(message, channel, state) do
    :luerl_heap.alloc_table(table(message, channel), state)
  end

  def table(%Message{id: id, content: content}, channel) do
    [
      {"channel", channel},
      {"id", id},
      {"content", content}
    ]
  end
end
