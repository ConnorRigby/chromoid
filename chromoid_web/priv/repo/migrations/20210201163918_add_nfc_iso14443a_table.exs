defmodule Chromoid.Repo.Migrations.AddNfcIso14443aTable do
  use Ecto.Migration

  def change do
    create table(:nfc_iso14443a) do
      add :device_id, references(:devices), null: false
      add :abtUid, :string, null: false
      add :abtAtq, :string, null: false
      add :abtAts, :string
      add :btSak, :integer, null: false
      timestamps()
    end

    create unique_index(:nfc_iso14443a, [:device_id, :abtUid])
  end
end
