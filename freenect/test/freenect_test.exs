defmodule FreenectTest do
  use ExUnit.Case
  doctest Freenect

  test "greets the world" do
    assert Freenect.hello() == :world
  end
end
