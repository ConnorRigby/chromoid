defmodule Chromoid.Devices.RelayStatus do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :state, :string, null: false
    field :at, :utc_datetime, null: false
  end

  def changeset(relay_status, attrs) do
    relay_status
    |> cast(attrs, [:state, :at])
    |> validate_required([:state, :at])
  end
end
