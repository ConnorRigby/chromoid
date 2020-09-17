defmodule Chromoid.BLEConnection.Registry do
  @doc false
  def child_spec(_) do
    Registry.child_spec(name: __MODULE__, keys: :unique)
  end

  @doc "Dynamic name generation"
  def via(addr) do
    {:via, Registry, {__MODULE__, addr}}
  end
end
