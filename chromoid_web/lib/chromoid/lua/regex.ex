defmodule Chromoid.Lua.Regex do
  use Chromoid.Lua.Module

  def table() do
    [
      {"match", erl_func(code: &match/2)},
      {"named_captures", erl_func(code: &named_captures/2)}
    ]
  end

  def match([regex, string] = args, state) do
    case Regex.compile(regex) do
      {:ok, regex} ->
        result = Regex.match?(regex, string)
        {[result], state}

      _error ->
        :luerl_lib.badarg_error("regex.match", args, state)
    end
  end

  def named_captures([regex, string] = args, state) do
    case Regex.compile(regex) do
      {:ok, regex} ->
        result = Regex.named_captures(regex, string)
        {result, state} = :luerl.encode(result, state)
        {[result], state}

      _error ->
        :luerl_lib.badarg_error("regex.match", args, state)
    end
  end
end
