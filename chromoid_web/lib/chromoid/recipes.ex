defmodule Chromoid.Recipes do
  import Ecto.Query, warn: false
  alias Chromoid.Repo

  alias Chromoid.Recipes.{
    Recipe
  }

  def change_recipe(recipe, attrs \\ %{}) do
    Recipe.changeset(recipe, attrs)
  end

  def new_recipe(recipe \\ %Recipe{}, attrs) do
    Recipe.changeset(recipe, attrs)
    |> Repo.insert()
  end

  def a(ingredients, steps, attrs) do
    ingredients =
      Enum.reduce(0..(Enum.count(ingredients) - 1), [], fn i, acc ->
        acc ++ [{i, Enum.at(ingredients, i)}]
      end)
      |> Map.new()

    steps =
      Enum.reduce(0..(Enum.count(steps) - 1), [], fn i, acc -> acc ++ [{i, Enum.at(steps, i)}] end)
      |> Map.new()

    Enum.into(%{"ingredients" => ingredients, "steps" => steps}, attrs)
  end

  def chili do
    a(
      [
        %{"name" => "onion", "unit" => "medium", "notes" => "chopped", "quantity" => 1},
        %{"name" => "garlic", "unit" => "cloves", "notes" => "minced", "quantity" => 4},
        %{"name" => "vegetable broth", "unit" => "cups", "quantity" => 3},
        %{"name" => "tomato sauce", "unit" => "ounce", "notes" => "can", "quantity" => 15},
        %{"name" => "diced tomato", "unit" => "ounce", "notes" => "can", "quantity" => 15},
        %{"name" => "kidney beans", "unit" => "ounce", "notes" => "can", "quantity" => 15},
        %{
          "name" => "kidney beans",
          "unit" => "ounce",
          "notes" => "can, drained, rinced",
          "quantity" => 15
        },
        %{
          "name" => "great northern beans",
          "unit" => "ounce",
          "notes" => "can, drained, rinced",
          "quantity" => 15
        },
        %{
          "name" => "black beans",
          "unit" => "ounce",
          "notes" => "can, drained, rinced",
          "quantity" => 15
        },
        %{
          "name" => "black beans",
          "unit" => "ounce",
          "notes" => "can, drained, rinced",
          "quantity" => 15
        },
        %{"name" => "cocoa powder", "unit" => "tablespoon", "quantity" => 1},
        %{"name" => "black pepper", "unit" => "teaspoon", "quantity" => 0.5},
        %{"name" => "chili powder", "unit" => "teaspoon", "quantity" => 0.5},
        %{"name" => "oregano", "unit" => "teaspoon", "quantity" => 0.5},
        %{"name" => "cayenne pepper", "unit" => "teaspoon", "quantity" => 0.8},
        %{"name" => "corn", "unit" => "cup", "quantity" => 1}
      ],
      [
        %{
          "content" => """
          In a large slow cooker, add all of the ingredients MINUS the corn.
          Mix well and cook for 2-3 hours on HIGH or 4-5 hours on LOW.
          """
        },
        %{
          "content" => """
          30 minutes before serving, add in the corn and allow the chili to continue
          cooking until the corn is cooked through.
          """
        },
        %{
          "content" => """
          Serve and ENJOY! Store in the fridge in an airtight
          container for up to a few days.
          """
        }
      ],
      %{"name" => "Vegan Crockpot Chili"}
    )
  end
end
