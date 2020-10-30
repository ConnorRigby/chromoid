defmodule ChromoidWeb.RecipeLive do
  use ChromoidWeb, :live_view

  alias Chromoid.{
    Recipes,
    Recipes.Recipe,
    Recipes.Ingredient,
    Recipes.Step
  }

  @impl true
  def mount(_params, _session, socket) do
    recipe = add_empty_stuff(%Recipe{ingredients: [], steps: []})

    changeset = Recipes.change_recipe(recipe)

    {:ok,
     socket
     |> assign(:recipe, recipe)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"recipe" => params}, socket) do
    changeset = Recipes.change_recipe(%Recipe{}, params) |> Map.put(:action, :insert)

    {:noreply,
     socket
     |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"recipe" => params}, socket) do
    case Recipes.new_recipe(params) do
      {:ok, recipe} ->
        {:noreply,
         socket
         |> put_flash(:info, "recipe created")
         |> assign(:recipe, add_empty_stuff(recipe))}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset, label: "error")

        {:noreply,
         socket
         |> put_flash(:error, "Could not save recipe")
         |> assign(changeset: changeset)}
    end
  end

  defp add_empty_stuff(recipe) do
    recipe
    |> add_empty_ingredient()
    |> add_empty_step()
  end

  defp add_empty_ingredient(%Recipe{ingredients: %Ecto.Association.NotLoaded{}}) do
    raise "Ingredients not loaded"
  end

  defp add_empty_ingredient(%Recipe{ingredients: ingredients} = recipe) do
    %Recipe{recipe | ingredients: [%Ingredient{} | ingredients]}
  end

  defp add_empty_step(%Recipe{steps: %Ecto.Association.NotLoaded{}}) do
    raise "Steps not loaded"
  end

  defp add_empty_step(%Recipe{steps: steps} = recipe) do
    %Recipe{recipe | steps: [%Step{} | steps]}
  end
end
