defmodule Chromoid.Lua do
  alias Chromoid.Lua.{
    Discord,
    Regex,
    Logger
  }

  @luerl_header Application.app_dir(:luerl, ["include", "luerl.hrl"])
  import Record, only: [defrecord: 2]
  defrecord :erl_func, Record.extract(:erl_func, from: @luerl_header)
  defrecord :userdata, Record.extract(:userdata, from: @luerl_header)

  def init(guild, user, script) do
    state = :luerl.init()
    state = :luerl.set_table(["_script"], {:userdata, script}, state)
    state = :luerl.set_table(["_guild"], {:userdata, guild}, state)
    state = :luerl.set_table(["_user"], {:userdata, user}, state)
    state = :luerl.set_table(["_self"], {:userdata, self()}, state)
    state = :luerl.set_table(["_client"], nil, state)

    state = :luerl.load_module(["discord"], Discord, state)
    state = :luerl.load_module(["regex"], Regex, state)
    state = :luerl.load_module(["logger"], Logger, state)
    state
  end
end
