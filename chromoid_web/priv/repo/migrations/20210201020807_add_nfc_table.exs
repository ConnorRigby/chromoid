defmodule Chromoid.Repo.Migrations.AddNfcTable do
  use Ecto.Migration

  def change do
    create table(:nfc) do
      add :device_id, references(:devices), null: false
      add :type, :string, null: false
      add :uid, :string, null: false
      timestamps()
    end

    create unique_index(:nfc, [:device_id, :uid])
  end
end
