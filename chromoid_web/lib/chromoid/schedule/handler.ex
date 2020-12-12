defmodule Chromoid.Schedule.Handler do
  @type schedule() :: Chromoid.Schedule.t()
  @callback start_link(schedule()) :: GenServer.on_start()

  @behaviour Ecto.Type

  def type, do: :string

  def cast("Elixir." <> _ = module) do
    String.to_atom(module)
    |> assert_impl
  end

  def cast(module) when is_atom(module) do
    assert_impl(module)
  end

  def load("Elixir." <> _ = module) do
    String.to_atom(module)
    |> assert_impl
  end

  def dump(module) when is_atom(module) do
    with {:ok, module} <- assert_impl(module) do
      {:ok, to_string(module)}
    else
      _ -> :error
    end
  end

  def assert_impl(module) when is_atom(module) do
    {:ok, module}
  end

  def embed_as(_format), do: :self

  def equal?(term, term), do: true
  def equal?(_, _), do: false
end
