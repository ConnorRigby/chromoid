defmodule Chromoid.Lua.Class do
  defmacro __using__(_opts) do
    quote location: :keep do
      @luerl_header Application.app_dir(:luerl, ["include", "luerl.hrl"])
      import Record, only: [defrecord: 2]
      defrecord :erl_func, Record.extract(:erl_func, from: @luerl_header)
    end
  end
end
