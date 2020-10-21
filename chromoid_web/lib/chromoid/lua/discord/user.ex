defmodule Chromoid.Lua.Discord.User do
  def alloc(%Nostrum.Struct.User{} = user, state) do
    :luerl_heap.alloc_table(table(user), state)
  end

  def table(%Nostrum.Struct.User{username: username}) do
    [
      {"username", username}
    ]
  end
end
