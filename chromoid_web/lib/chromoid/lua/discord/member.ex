defmodule Chromoid.Lua.Discord.Member do
  use Chromoid.Lua.Class
  import Chromoid.Lua.Discord, only: [schedule_action: 2]

  def alloc(%Nostrum.Struct.Guild.Member{} = member, user, state) do
    :luerl_heap.alloc_table(table(member, user), state)
  end

  def table(%Nostrum.Struct.Guild.Member{}, user) do
    [
      {"user", user},
      {"addRole", erl_func(code: &add_role/2)}
    ]
  end

  def add_role([self, role_id], state) do
    {user, state} = :luerl_emul.get_table_key(self, "user", state)
    {user_id, state} = :luerl_emul.get_table_key(user, "id", state)
    {{:userdata, guild}, state} = :luerl.get_table(["_guild"], state)
    schedule_action({:add_guile_member_role, [guild.id, user_id, role_id]}, state)
  end
end
