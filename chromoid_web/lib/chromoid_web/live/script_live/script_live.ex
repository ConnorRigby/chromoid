defmodule ChromoidWeb.ScriptLive do
  use ChromoidWeb, :live_view
  require Logger

  @impl true
  def mount(params, %{"user_token" => token}, socket) do
    user = Chromoid.Accounts.get_user_by_session_token(token)

    changeset =
      Ecto.build_assoc(user, :scripts)
      |> Chromoid.Lua.Script.create_changeset(%{})

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:changeset, changeset)
     |> assign(:scripts, user.scripts)
     |> assign(:modal_script_id, params["id"])
     |> assign(:modal_script, nil)}
  end

  @impl true
  def handle_event("show_modal", %{"script_id" => script_id}, socket) do
    script = Chromoid.Lua.ScriptStorage.load_script(script_id)

    {:noreply,
     socket
     |> assign(:modal_script_id, script_id)
     |> assign(:modal_script, script)}
  end

  def handle_event("validate", %{"script" => params}, socket) do
    changeset = Chromoid.Lua.Script.create_changeset(socket.assigns.changeset, params)

    {:noreply,
     socket
     |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"script" => params}, socket) do
    case Chromoid.Lua.ScriptStorage.new_script_for_user(socket.assigns.user, params) do
      {:ok, script} ->
        scripts = Chromoid.Repo.preload(socket.assigns.user, :scripts).scripts

        {:noreply,
         socket
         |> put_flash(:info, "Script created: #{script.filename}")
         |> assign(:scripts, scripts)
         |> redirect(to: Routes.script_path(socket, :edit, script))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "error creating script: #{inspect(reason)}")}
    end
  end

  def handle_event("delete", %{"script_id" => id}, socket) do
    script = Chromoid.Lua.ScriptStorage.load_script(id)
    Chromoid.Lua.ScriptStorage.mark_deleted(script)
    scripts = Chromoid.Repo.preload(socket.assigns.user, :scripts).scripts

    {:noreply,
     socket
     |> assign(:scripts, scripts)}
  end

  def handle_event("hide_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:modal_script_id, nil)}
  end
end
