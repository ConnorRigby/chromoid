defmodule Chromoid.Repo.Migrations.DropNfcTable do
  use Ecto.Migration

  def change do
    drop unique_index(:nfc, [:device_id, :uid])
    drop table(:nfc)
  end
end
