defmodule Chromoid.Devices.Schedule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "device_schedules" do
    belongs_to :device, Chromoid.Devices.Device
    has_many :executions, Chromoid.Devices.Schedule.Execution
    field :next_execution, :utc_datetime, virtual: true
    field :pattern, :string, null: false
    field :epoch, :utc_datetime
    field :timezone, :integer, null: false, default: -2
    timestamps()
  end

  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [:pattern, :epoch, :timezone])
    |> validate_required([:pattern, :epoch, :timezone])
  end
end
