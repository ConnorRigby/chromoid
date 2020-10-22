defmodule Chromoid.Lua.Module do
  import Record, only: [defrecord: 2]
  @luerl_header Application.app_dir(:luerl, ["include", "luerl.hrl"])
  defrecord :luerl, Record.extract(:luerl, from: @luerl_header)
  defrecord :tref, Record.extract(:tref, from: @luerl_header)

  @type luerl :: record(:luerl, [])
  @type tref :: record(:tref, [])

  defmacro __using__(_opts) do
    quote location: :keep do
      use Chromoid.Lua.Class

      @behaviour Chromoid.Lua.Module

      @impl Chromoid.Lua.Module
      def install(state), do: :luerl_heap.alloc_table(table(), state)

      @impl Chromoid.Lua.Module
      def table(), do: []

      defoverridable(Chromoid.Lua.Module)
    end
  end

  @callback install(luerl) :: {tref, luerl}
  @callback table() :: list()
end
