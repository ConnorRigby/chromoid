defmodule Chromoid.Lua.Discord.User do
  use Chromoid.Lua.Class, :new
  alias Chromoid.Lua.Discord.User.Flags

  alloc properties: [
          avatar: :string,
          bot: :boolean,
          discriminator: :string,
          email: :string,
          id: :integer,
          mfa_enabled: :boolean,
          username: :string,
          verified: :boolean,
          # public_flags: public_flags,
          # methods
          mention: &mention/2
          # private
          # _user: userdata(d: user)}
        ]

  # def alloc(%Nostrum.Struct.User{} = user, state) do
  #   {public_flags, state} = Flags.alloc(user.public_flags, state)
  #   :luerl_heap.alloc_table(table(user, public_flags), state)
  # end

  # def table(
  #       %Nostrum.Struct.User{
  #         avatar: avatar,
  #         bot: bot,
  #         discriminator: discriminator,
  #         email: email,
  #         id: id,
  #         mfa_enabled: mfa_enabled,
  #         username: username,
  #         verified: verified
  #       } = user,
  #       public_flags
  #     ) do
  #   [
  #     {"avatar", avatar},
  #     {"bot", bot},
  #     {"discriminator", discriminator},
  #     {"email", email},
  #     {"id", id},
  #     {"mfa_enabled", mfa_enabled},
  #     {"username", username},
  #     {"verified", verified},
  #     {"public_flags", public_flags},
  #     # methods
  #     {"mention", erl_func(code: &mention/2)},
  #     # private
  #     {"_user", userdata(d: user)}
  #   ]
  # end

  def mention([self | _], state) do
    {id, state} = :luerl_emul.get_table_key(self, "id", state)
    # user = userdata(user)[:d]
    {[Nostrum.Struct.User.mention(%Nostrum.Struct.User{id: id})], state}
  end
end

defimpl Chromoid.Lua.Object, for: Nostrum.Struct.User do
  def to_lua(user, properties) do
    [
      {"avatar", user.avatar},
      {"bot", user.bot},
      {"discriminator", user.discriminator},
      {"email", user.email},
      {"id", user.id},
      {"mfa_enabled", user.mfa_enabled},
      {"username", user.username},
      {"verified", user.verified},
      # {"public_flags", public_flags},
      # methods
      {"mention", properties[:mention]}
    ]
  end
end
