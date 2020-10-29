defmodule Chromoid.Recipes.Tag do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "recipe_tags" do
    belongs_to :recipe, Chromoid.Recipes.Recipe
    field :name, :string
    timestamps()
  end
end
