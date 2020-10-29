defmodule Chromoid.Recipes.Step do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "recipe_steps" do
    has_many :ingredients, Chromoid.Recipes.Ingredient
    belongs_to :recipe, Chromoid.Recipes.Recipe
    field :content, :string
    timestamps()
  end

  def changeset(step, attrs \\ %{}) do
    step
    |> cast(attrs, [:content])
    |> validate_required([:content])
  end
end
