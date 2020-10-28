defmodule ChromoidWeb.ScriptController do
  use ChromoidWeb, :controller
  require Logger

  def edit(conn, %{"id" => id}) do
    script = Chromoid.Lua.ScriptStorage.load_script(id)
    changeset = Chromoid.Lua.Script.changeset(script, %{})
    render(conn, "edit.html", script: script, action: "/scripts/#{id}", changeset: changeset)
  end

  def update(conn, %{"script_id" => id, "script" => attrs} = params) do
    script = Chromoid.Lua.ScriptStorage.load_script(id)
    changeset = Chromoid.Lua.Script.changeset(script, attrs)

    case Chromoid.Repo.update(changeset) do
      {:ok, script} ->
        if script.active || params["reload"] do
          for {id, guild} <- ChromoidDiscord.GuildCache.list_guilds() do
            Logger.info("Activating script for guild: #{id}")
            ChromoidDiscord.Guild.LuaConsumer.activate_script(guild, script)
          end
        end

        if !script.active do
          Logger.info("Deactivating script")
          Chromoid.Lua.ScriptStorage.handle_deactivation(script)
        end

        redirect(conn, to: Routes.script_path(conn, :edit, script))

      {:error, changeset} ->
        render(conn, "edit.html", script: script, action: "/scripts/#{id}", changeset: changeset)
    end
  end

  def save(conn, %{"content" => content, "script_id" => id}) do
    Logger.info("Saving script")
    script = Chromoid.Lua.ScriptStorage.load_script(id)
    script = %{script | content: content}

    case Chromoid.Lua.ScriptStorage.save_script(script) do
      {:ok, script} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          200,
          Jason.encode!(%{
            id: script.id,
            content: script.content,
            filename: script.filename
          })
        )

      {:error, errors, _idk?} ->
        send_error(conn, errors, [])

      error ->
        IO.inspect(error, label: "unknown error")
        send_error(conn, [], [%{type: "save", reason: "unknown error"}])
    end
  end

  def send_error(conn, errors, acc)

  def send_error(conn, [{line, :luerl_parse, reason} | rest], acc) do
    error = %{type: "parse", line: line, reason: to_string(reason)}
    send_error(conn, rest, [error | acc])
  end

  def send_error(conn, [], errors) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      400,
      Jason.encode!(%{
        errors: Enum.reverse(errors)
      })
    )
  end
end
