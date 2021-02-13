defmodule ChessTest do
  use ExUnit.Case
  doctest Chess

  test "greets the world" do
    assert Chess.hello() == :world
  end
end
