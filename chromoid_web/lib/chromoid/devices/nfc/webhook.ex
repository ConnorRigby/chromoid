defmodule Chromoid.Devices.NFC.WebHook do
  use Ecto.Schema
  import Ecto.Changeset
  alias Chromoid.Devices.NFC.WebHook

  @json_library Application.get_env(:phoenix, :json_library) || Jason

  schema "nfc_webhooks" do
    belongs_to :nfc_iso14443a, Chromoid.Devices.NFC.ISO14443a
    field :url, :string, null: false
    field :secret, :string, null: false
    timestamps()
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:url])
    |> generate_secret()
    |> validate_required([:url, :secret])
    |> unique_constraint([:nfc_iso14443a_id, :url], message: "Webhook already exists for that URL")
  end

  def generate_secret(changeset) do
    secret = :crypto.strong_rand_bytes(16) |> Base.encode16()
    put_change(changeset, :secret, secret)
  end

  def execute(%WebHook{url: url, secret: secret}, nfc) do
    HTTPoison.post(url, body(nfc), headers(secret), hackney: [pool: :nfc_webhooks])
  end

  def body(%{abtUid: abtUid, abtAtq: abtAtq, abtAts: abtAts, btSak: btSak}) do
    @json_library.encode!(%{abtUid: abtUid, abtAtq: abtAtq, abtAts: abtAts, btSak: btSak})
  end

  def headers(secret) do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"X-Chromoid-Secret", secret}
    ]
  end
end
