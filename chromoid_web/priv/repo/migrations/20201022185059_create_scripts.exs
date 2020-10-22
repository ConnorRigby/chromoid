defmodule Chromoid.Repo.Migrations.CreateScripts do
  use Ecto.Migration

  def change do
    create table(:scripts) do
      add :created_by_id, references(:users), null: false
      add :path, :string, null: false
      add :filename, :string, null: false
      add :subsystem, :string, null: false
      timestamps()
    end

    create unique_index(:scripts, [:created_by_id, :filename])
  end
end
