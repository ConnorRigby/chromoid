defmodule Chromoid.Repo.Migrations.AddNfcActionsTable do
  use Ecto.Migration

  def change do
    create table(:nfc_actions) do
      add :nfc_iso14443a_id, references(:nfc_iso14443a), null: false
      add :module, :string, null: false
      add :args, :map, null: false, default: %{}
      timestamps()
    end
  end
end
