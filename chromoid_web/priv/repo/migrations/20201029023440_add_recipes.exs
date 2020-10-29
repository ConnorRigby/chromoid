defmodule Chromoid.Repo.Migrations.AddRecipes do
  use Ecto.Migration

  def change do
    create table(:recipes) do
      add :name, :string, null: false
      add :user_id, references(:users)
      timestamps()
    end

    create table(:steps) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), null: false
      add :content, :string
      timestamps()
    end

    create table(:ingredients) do
      add :recipe_id, references(:recipes, on_delete: :delete_all), null: false
      add :step_id, references(:steps, on_delete: :delete_all), null: false
      add :unit, :string, null: false
      add :quantity, :float, null: false
      add :notes, :string, null: false, default: ""
      timestamps()
    end
  end
end
