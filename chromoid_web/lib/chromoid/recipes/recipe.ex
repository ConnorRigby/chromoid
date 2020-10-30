defmodule Chromoid.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "recipes" do
    belongs_to :created_by, Chromoid.Accounts.User
    has_many :ingredients, Chromoid.Recipes.Ingredient
    has_many :steps, Chromoid.Recipes.Step
    has_many :tags, Chromoid.Recipes.Tag
    field :name, :string
    timestamps()
  end

  def changeset(recipe, attrs \\ %{}) do
    recipe
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> cast_assoc(:ingredients, required: true)
    |> cast_assoc(:steps, required: false)
  end
end
