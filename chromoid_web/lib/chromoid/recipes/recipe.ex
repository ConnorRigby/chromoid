defmodule Chromoid.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "recipes" do
    belongs_to :created_by, Chromoid.Accounts.User
    has_many :ingredients, Chromoid.Recipes.Ingredient
    has_many :steps, Chromoid.Recpies.Step
    has_many :tags, Chromoid.Recipes.Tag
    field :name, :string
    timestamps()
  end
end
