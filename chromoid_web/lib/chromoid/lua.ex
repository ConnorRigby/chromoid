defmodule Chromoid.Lua do
  alias Chromoid.Lua.Discord
  @luerl_header Application.app_dir(:luerl, ["include", "luerl.hrl"])
  import Record, only: [defrecord: 2]
  defrecord :erl_func, Record.extract(:erl_func, from: @luerl_header)
  defrecord :userdata, Record.extract(:userdata, from: @luerl_header)

  def init(guild, user) do
    state = :luerl.init()

    state =
      :luerl.set_table(
        ["_discord"],
        [
          {"_guild", {:userdata, guild}},
          {"_user", {:userdata, user}},
          {"_self", {:userdata, self()}}
        ],
        state
      )

    # state = :luerl.set_table(["_G", "_guild"], , state)
    # state = :luerl.set_table(["_G", "_user"], user, state)
    :luerl.load_module(["discord"], Discord, state)
  end
end
