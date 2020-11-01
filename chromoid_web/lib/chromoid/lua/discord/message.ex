defmodule Chromoid.Lua.Discord.Message do
  use Chromoid.Lua.Class
  alias Chromoid.Lua.Discord.User

  alias Nostrum.Struct.Message

  def alloc(message, channel, state) do
    {author, state} = User.alloc(message.author, state)
    :luerl_heap.alloc_table(table(message, channel, author), state)
  end

  def table(%Message{id: id, content: content}, channel, author) do
    [
      {"channel", channel},
      {"id", id},
      {"content", content},
      {"author", author}
    ]
  end
end
