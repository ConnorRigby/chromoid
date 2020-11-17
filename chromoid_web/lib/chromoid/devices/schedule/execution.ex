defmodule Chromoid.Devices.Schedule.Execution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "schedule_executions" do
    belongs_to :schedule, Chromoid.Devices.Schedule
    field :errors, :string
    field :at, :utc_datetime, null: false
    timestamps()
  end

  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [:errors, :at])
    |> validate_required([:errors, :at])
  end
end
