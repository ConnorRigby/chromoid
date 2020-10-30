defmodule Chromoid.Lua.LoggerTest do
  use ExUnit.Case
  alias Chromoid.{Lua, Lua.Script}

  test "regex.match" do
    script = %Script{id: 123, filename: "test.lua"}
    lua = Lua.init(nil, nil, script)
    id = script.id

    {[value], _lua} =
      :luerl.do(
        """
        logger.debug("hello, world")
        logger.info("hello, world")
        logger.warn("hello, world")
        logger.error("hello, world")
        logger.bare_log("debug", "hello, world x2")

        return true
        """,
        lua
      )

    assert value
    assert_receive {:log, ^id, "debug", "hello, world"}
    assert_receive {:log, ^id, "info", "hello, world"}
    assert_receive {:log, ^id, "warn", "hello, world"}
    assert_receive {:log, ^id, "error", "hello, world"}
    assert_receive {:log, ^id, "debug", "hello, world x2"}
  end
end
