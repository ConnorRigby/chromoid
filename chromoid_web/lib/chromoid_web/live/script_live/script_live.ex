defmodule ChromoidWeb.ScriptLive do
  use ChromoidWeb, :live_view
  require Logger

  @impl true
  def mount(params, %{"user_token" => token}, socket) do
    user = Chromoid.Accounts.get_user_by_session_token(token)

    {:ok,
     socket
     |> assign(:user, user)
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

  def handle_event("hide_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:modal_script_id, nil)}
  end
end
