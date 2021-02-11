defmodule Chromoid.Devices.NFC.Action.Name do
  @behaviour Ecto.Type

  def type, do: :string

  def cast(value) when is_atom(value), do: {:ok, value}
  def cast(value) when is_binary(value), do: {:ok, String.to_existing_atom(value)}

  def cast(_), do: :error

  def load(value), do: {:ok, String.to_existing_atom(value)}

  def dump(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def dump(_), do: :error

  def equal?(term, term), do: true
  def equal?(_, _), do: false

  def embed_as(_format), do: :self
end
