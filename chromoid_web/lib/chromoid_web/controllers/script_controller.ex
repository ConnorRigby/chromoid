defmodule ChromoidWeb.ScriptController do
  use ChromoidWeb, :controller

  def edit(conn, %{"id" => id}) do
    script = Chromoid.Lua.ScriptStorage.load_script(id)
    render(conn, "edit.html", script: script, action: "/scripts/#{id}")
  end
end
