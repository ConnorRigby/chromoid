defmodule Chromoid.Repo.Migrations.AddRecipesAttempt2 do
  use Ecto.Migration

  def change do
    alter table(:recipes) do
      add :created_by_id, references(:users)
    end
  end
end
