defmodule Chromoid.Lua.RegexTest do
  use ExUnit.Case
  alias Chromoid.{Lua, Lua.Script}

  test "regex.match" do
    script = %Script{filename: "test.lua"}
    lua = Lua.init(nil, nil, script)

    {[value], _lua} =
      :luerl.do(
        """
        return regex.match("foo", "foo")
        """,
        lua
      )

    assert value
  end

  test "regex.match error" do
    script = %Script{filename: "test.lua"}
    lua = Lua.init(nil, nil, script)

    assert {:lua_error, {:badarg, "regex.match", ["*foo", "foo"]}, _lua} =
             catch_error(
               :luerl.do(
                 """
                 return regex.match("*foo", "foo")
                 """,
                 lua
               )
             )

    # assert :new_luerl.get_stacktrace(lua)
  end

  test "regex.named_captures" do
    script = %Script{filename: "test.lua"}
    lua = Lua.init(nil, nil, script)

    {[value], _lua} =
      :luerl.do(
        """
        return regex.named_captures("c(?<foo>d)", "abcd")
        """,
        lua
      )

    assert value == %{"foo" => "d"}
  end
end
