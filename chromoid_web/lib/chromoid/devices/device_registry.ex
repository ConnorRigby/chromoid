defmodule Chromoid.Devices.DeviceRegistry do
  def child_spec(_) do
    Registry.child_spec(name: __MODULE__, keys: :unique)
  end

  @doc "Dynamic name generation"
  def via(id) do
    {:via, Registry, {__MODULE__, id}}
  end
end
