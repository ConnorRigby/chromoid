defmodule Chromoid.Lua.Discord.Message do
  # use Chromoid.Lua.Class
  # alias Chromoid.Lua.Discord.{User, Member}

  # alias Nostrum.Struct.Message

  # def alloc(message, channel, state) do
  #   {author, state} = User.alloc(message.author, state)
  #   {member, state} = Member.alloc(message.member, author, state)
  #   :luerl_heap.alloc_table(table(message, channel, author, member), state)
  # end

  # def table(%Message{id: id, content: content}, channel, author, member) do
  #   [
  #     {"channel", channel},
  #     {"id", id},
  #     {"content", content},
  #     {"author", author},
  #     {"member", member}
  #   ]
  # end

  use Chromoid.Lua.Class, :new

  alloc properties: [
          channel: Chromoid.Lua.Discord.Channel,
          member: Chromoid.Lua.Discord.Member,
          author: Chromoid.Lua.Discord.User,
          id: :integer,
          content: :string
        ]
end

defimpl Chromoid.Lua.Object, for: Nostrum.Struct.Message do
  def to_lua(message, properties) do
    IO.inspect(properties, label: "message props")

    [
      {"channel", properties[:channel]},
      {"id", message.id},
      {"content", message.content},
      {"author", properties[:author]},
      {"member", properties[:member]}
    ]
  end
end
