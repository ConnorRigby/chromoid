defmodule Chromoid.Devices.Job.Job do
  use Chromoid.Devices.Job.Schema
  import Ecto.Changeset
  alias Chromoid.Devices.Job.{File, Filament}

  embedded_schema do
    embeds_one :file, File
    field :estimatedPrintTime, :float
    field :lastPrintTime, :integer
    embeds_one :filament, Filament
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:estimatedPrintTime, :lastPrintTime])
    |> cast_embed(:file, required: true)
    |> cast_embed(:filament, required: true)
  end
end
