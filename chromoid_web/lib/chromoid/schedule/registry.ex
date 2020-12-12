defmodule Chromoid.Schedule.Registry do
  @moduledoc "Wrapper around Elixir.Registry to track names of stages in a guild"

  @doc false
  def child_spec(_) do
    Registry.child_spec(name: __MODULE__, keys: :unique)
  end

  @doc "Dynamic name generation"
  def via(%Chromoid.Schedule{id: id}, module) do
    {:via, Registry, {__MODULE__, Module.concat(module, to_string(id))}}
  end
end
