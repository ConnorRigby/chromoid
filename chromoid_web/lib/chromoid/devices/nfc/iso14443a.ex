defmodule Chromoid.Devices.NFC.ISO14443a do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nfc_iso14443a" do
    belongs_to :device, Chromoid.Devices.Device
    field :abtUid, :string, null: false
    field :abtAtq, :string, null: false
    field :abtAts, :string
    field :btSak, :integer, null: false
    has_many :webhooks, Chromoid.Devices.NFC.WebHook, foreign_key: :nfc_iso14443a_id
    has_many :actions, Chromoid.Devices.NFC.Action, foreign_key: :nfc_iso14443a_id
    timestamps()
  end

  def changeset(nfc, attrs) do
    nfc
    |> cast(attrs, [:abtAtq, :abtUid, :abtAts, :btSak])
    |> validate_required([:abtAtq, :abtUid, :btSak])
    |> unique_constraint([:device_id, :abtUid], message: "UID already taken for this device")
  end
end
