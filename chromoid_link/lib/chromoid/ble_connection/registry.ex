defmodule Chromoid.BLEConnection.Registry do
  @doc false
  def child_spec(_) do
    Registry.child_spec(name: __MODULE__, keys: :unique)
  end

  @doc "Dynamic name generation"
  def via(%{address: addr}, module) do
    {:via, Registry, {__MODULE__, module}}
  end
end
