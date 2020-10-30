defmodule Chromoid.Recipes do
  import Ecto.Query, warn: false
  alias Chromoid.Repo

  alias Chromoid.Recipes.{
    Recipe
  }

  def change_recipe(recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end

  def new_recipe(attrs) do
    Recipe.changeset(%Recipe{}, attrs)
    |> Repo.insert()
  end
end
