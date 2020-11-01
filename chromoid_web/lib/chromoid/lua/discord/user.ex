defmodule Chromoid.Lua.Discord.User do
  use Chromoid.Lua.Class
  alias Chromoid.Lua.Discord.User.Flags

  def alloc(%Nostrum.Struct.User{} = user, state) do
    {public_flags, state} = Flags.alloc(user.public_flags, state)
    :luerl_heap.alloc_table(table(user, public_flags), state)
  end

  def table(
        %Nostrum.Struct.User{
          avatar: avatar,
          bot: bot,
          discriminator: discriminator,
          email: email,
          id: id,
          mfa_enabled: mfa_enabled,
          username: username,
          verified: verified
        } = user,
        public_flags
      ) do
    [
      {"avatar", avatar},
      {"bot", bot},
      {"discriminator", discriminator},
      {"email", email},
      {"id", id},
      {"mfa_enabled", mfa_enabled},
      {"username", username},
      {"verified", verified},
      {"public_flags", public_flags},
      # methods
      {"mention", erl_func(code: &mention/2)},
      # private
      {"_user", userdata(d: user)}
    ]
  end

  def mention([self | _], state) do
    {user, state} = :luerl_emul.get_table_key(self, "_user", state)
    user = userdata(user)[:d]
    {[Nostrum.Struct.User.mention(user)], state}
  end
end
