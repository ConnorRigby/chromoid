defmodule Chromoid.Lua.ScriptStorage do
  alias Chromoid.Repo
  import Ecto.Query, warn: false

  @root_dir Application.get_env(:chromoid, __MODULE__)[:root_dir]
  @root_dir ||
    Mix.raise("""
    Script root dir is not configured
    """)

  alias Chromoid.Lua.Script

  def new_script_for_user(user, filename) do
    attrs = %{
      subsystem: "discord",
      filename: filename,
      path: Path.join(@root_dir, Ecto.UUID.generate())
    }

    changeset =
      Ecto.build_assoc(user, :scripts)
      |> Script.changeset(attrs)

    with {:ok, script} <- Repo.insert(changeset) do
      case File.touch(script.path, NaiveDateTime.to_erl(script.inserted_at)) do
        :ok ->
          {:ok, %{script | content: ""}}

        {:error, reason} ->
          _ = Repo.delete!(script)
          raise File.Error, action: "touch", reason: reason, path: script.path
      end
    end
  end

  def save_script(%Script{content: nil, path: path}) do
    raise File.Error, action: "write", reason: :einval, path: path
  end

  def save_script(script) do
    :ok = File.write!(script.path, script.content)
    changeset = Script.changeset(script, %{})

    with {:ok, _chunk, _} <- :luerl.load(script.content, :luerl.init()),
         {:ok, script} <- Chromoid.Repo.update!(changeset, force: true) do
      case File.touch(script.path, NaiveDateTime.to_erl(script.updated_at)) do
        :ok ->
          {:ok, script}

        {:error, reason} ->
          _ = Repo.delete!(script)
          raise File.Error, action: "touch", reason: reason, path: script.path
      end
    end
  end

  def load_script(%Script{} = script) do
    content = File.read!(script.path)
    %{script | content: content}
  end

  def load_script(id) do
    Repo.get!(Script, id)
    |> load_script()
  end
end
