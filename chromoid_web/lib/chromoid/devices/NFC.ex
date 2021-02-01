defmodule Chromoid.Devices.NFC do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nfc" do
    belongs_to :device, Chromoid.Devices.Device
    field :type, :string, null: false
    field :uid, :string, null: false
    timestamps()
  end

  def changeset(nfc, attrs) do
    nfc
    |> cast(attrs, [:type, :uid])
    |> validate_required([:type, :uid])
    |> unique_constraint([:device_id, :uid], message: "UID already taken for this device")
  end
end
