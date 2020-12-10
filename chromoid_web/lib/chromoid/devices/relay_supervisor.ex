defmodule Chromoid.Devices.RelaySupervisor do
  use DynamicSupervisor

  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def start_child(params) do
    spec = {Chromoid.Devices.Relay, params}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_child(child) do
    DynamicSupervisor.terminate_child(__MODULE__, child)
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
