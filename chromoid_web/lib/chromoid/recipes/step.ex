defmodule Chromoid.Recipes.Step do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "steps" do
    has_many :ingredients, Chromoid.Recipes.Ingredient
    field :content, :string
    timestamps()
  end
end
