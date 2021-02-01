defmodule Chromoid.Repo.Migrations.AddNfcWebhooksTable do
  use Ecto.Migration

  def change do
    create table(:nfc_webhooks) do
      add :nfc_iso14443a_id, references(:nfc_iso14443a), null: false
      add :url, :string, null: false
      add :secret, :string, null: false
      timestamps()
    end

    create unique_index(:nfc_webhooks, [:nfc_iso14443a_id, :url])
  end
end
