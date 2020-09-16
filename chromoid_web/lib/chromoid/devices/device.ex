defmodule Chromoid.Devices.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field :serial, :string
    has_one :device_token, Chromoid.Devices.DeviceToken
    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
