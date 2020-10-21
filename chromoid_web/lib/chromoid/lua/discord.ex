defmodule Chromoid.Lua.Discord do
  use Chromoid.Lua.Module

  alias Chromoid.Lua.Discord.{
    User,
    Client
  }

  def table() do
    [
      {"Client", erl_func(code: &client/2)}
    ]
  end

  def client([], state) do
    {{:userdata, _guild}, state} = :luerl.get_table(["_discord", "_guild"], state)
    {{:userdata, current_user}, state} = :luerl.get_table(["_discord", "_user"], state)
    {user, state} = User.alloc(current_user, state)
    {client, state} = Client.alloc(user, state)
    {[client], state}
  end
end
