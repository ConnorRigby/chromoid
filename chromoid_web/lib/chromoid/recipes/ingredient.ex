defmodule Chromoid.Recipes.Ingredient do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "recipe_ingredients" do
    belongs_to :recipe, Chromoid.Recipes.Recipe
    belongs_to :step, Chromoid.Recipes.Step
    field :unit, :string, null: false
    field :quantity, :float, null: false
    field :name, :string, null: false
    field :notes, :string, null: false, default: ""
    timestamps()
  end

  def changeset(ingredient, attrs) do
    ingredient
    |> cast(attrs, [:unit, :quantity, :name, :notes])
    |> validate_required([:unit, :quantity, :name])
  end
end
