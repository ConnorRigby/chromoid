defmodule Chromoid.Devices.Job.Filament do
  use Chromoid.Devices.Job.Schema
  import Ecto.Changeset

  embedded_schema do
    field :length, :integer
    field :volume, :integer
  end

  def changeset(filament, attrs) do
    filament
    |> cast(attrs, [:length, :volume])
  end
end
