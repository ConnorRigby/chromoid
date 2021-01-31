defmodule NfcTest do
  use ExUnit.Case
  doctest Nfc

  test "greets the world" do
    assert Nfc.hello() == :world
  end
end
