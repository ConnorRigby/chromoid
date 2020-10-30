defmodule Chromoid.Lua.Logger do
  use Chromoid.Lua.Module

  def table() do
    [
      {"debug", erl_func(code: &debug/2)},
      {"info", erl_func(code: &info/2)},
      {"warn", erl_func(code: &warn/2)},
      {"error", erl_func(code: &error/2)},
      {"bare_log", erl_func(code: &bare_log/2)}
    ]
  end

  def debug(args, state) do
    bare_log(["debug" | args], state)
  end

  def info(args, state) do
    bare_log(["info" | args], state)
  end

  def warn(args, state) do
    bare_log(["warn" | args], state)
  end

  def error(args, state) do
    bare_log(["error" | args], state)
  end

  def bare_log([level, message], state) do
    {{:userdata, script}, state} = :luerl.get_table(["_script"], state)
    {{:userdata, pid}, state} = :luerl.get_table(["_self"], state)
    send(pid, {:log, script.id, level, message})
    {[true], state}
  end
end
