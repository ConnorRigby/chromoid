defmodule Chromoid.Devices.Job.Progress do
  use Chromoid.Devices.Job.Schema
  import Ecto.Changeset

  embedded_schema do
    field :completion, :float
    field :filepos, :integer
    field :printTime, :integer
    field :printTimeLeft, :integer
    field :printTimeLeftOrigin, :string
  end

  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [:completion, :filepos, :printTime, :printTimeLeft, :printTimeLeftOrigin])
  end
end
