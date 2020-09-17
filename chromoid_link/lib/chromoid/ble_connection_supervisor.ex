defmodule Chromoid.BLEConnectionSupervisor do
  use DynamicSupervisor

  def create_connection(args) do
    spec = {Chromoid.BLEConnection, args}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc false
  def start_link(args) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
