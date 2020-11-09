defmodule Chromoid.Devices.Job do
  use Chromoid.Devices.Job.Schema
  import Ecto.Changeset

  alias Chromoid.Devices.Job.{
    Job,
    Progress
  }

  embedded_schema do
    embeds_one :job, Job
    embeds_one :progress, Progress
    field :state, :string
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:state])
    |> cast_embed(:job, required: true)
    |> cast_embed(:progress, required: true)
  end
end
