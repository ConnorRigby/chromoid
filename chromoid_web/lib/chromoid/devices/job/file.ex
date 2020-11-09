defmodule Chromoid.Devices.Job.File do
  use Chromoid.Devices.Job.Schema
  import Ecto.Changeset

  embedded_schema do
    field :date, :integer
    field :display, :string
    field :name, :string
    field :origin, :string
    field :path, :string
    field :size, :integer
  end

  def changeset(file, attrs) do
    file
    |> cast(attrs, [:date, :display, :name, :origin, :path, :size])
  end
end
