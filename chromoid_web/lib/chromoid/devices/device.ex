defmodule Chromoid.Devices.Device do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devices" do
    field :serial, :string
    field :avatar_url, :string
    has_one :device_token, Chromoid.Devices.DeviceToken
    belongs_to :camera_differ, Chromoid.Devices.Device
    # has_many :schedules, Chromoid.Devices.Schedule

    many_to_many :guild_devices, Chromoid.Devices.GuildDevice,
      join_through: Chromoid.Devices.GuildDevice

    timestamps()
  end

  @doc false
  def changeset(device, attrs) do
    device
    |> cast(attrs, [:name, :avatar_url])
    |> validate_required([:name])
  end
end
