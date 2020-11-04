defmodule Chromoid.Lua.Discord.Message do
  use Chromoid.Lua.Class
  alias Chromoid.Lua.Discord.{User, Member}

  alias Nostrum.Struct.Message

  def alloc(message, channel, state) do
    {author, state} = User.alloc(message.author, state)
    {member, state} = Member.alloc(message.member, author, state)
    :luerl_heap.alloc_table(table(message, channel, author, member), state)
  end

  def table(%Message{id: id, content: content}, channel, author, member) do
    [
      {"channel", channel},
      {"id", id},
      {"content", content},
      {"author", author},
      {"member", member}
    ]
  end
end
