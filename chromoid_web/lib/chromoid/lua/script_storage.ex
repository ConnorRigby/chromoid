defmodule Chromoid.Lua.ScriptStorage do
  alias Chromoid.Repo
  import Ecto.Query, warn: false

  @root_dir Application.get_env(:chromoid, __MODULE__)[:root_dir]

  alias Chromoid.Lua.Script
  require Logger

  def new_script_for_user(user, attrs) do
    attrs =
      Map.merge(attrs, %{
        "subsystem" => "discord",
        "path" => Path.join(@root_dir, [Ecto.UUID.generate(), ".lua"])
      })

    changeset =
      Ecto.build_assoc(user, :scripts)
      |> Script.changeset(attrs)

    with {:ok, script} <- Repo.insert(changeset),
         :ok <- File.write!(script.path, default_content(user, script)) do
      case File.touch(script.path, NaiveDateTime.to_erl(script.inserted_at)) do
        :ok ->
          {:ok, %{script | content: default_content(user, script)}}

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
         {:ok, script} <- Chromoid.Repo.update(changeset, force: true) do
      case File.touch(script.path, NaiveDateTime.to_erl(script.updated_at)) do
        :ok ->
          {:ok, script}

        {:error, reason} ->
          _ = Repo.delete!(script)
          raise File.Error, action: "touch", reason: reason, path: script.path
      end
    end
  end

  def handle_deactivation(%Script{content: nil, path: path}) do
    raise File.Error, action: "read", reason: :einval, path: path
  end

  def handle_deactivation(script) do
    if !script.active do
      for {id, guild} <- ChromoidDiscord.GuildCache.list_guilds() do
        Logger.info("Deactivating script for guild: #{id}")
        ChromoidDiscord.Guild.LuaConsumer.deactivate_script(guild, script)
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

  def mark_deleted(script) do
    Script.delete_changeset(script)
    |> Repo.update!()
  end

  def activate(script) do
    Script.activate_changeset(script, true)
    |> Repo.update!()
  end

  def deactivate(script) do
    Script.activate_changeset(script, false)
    |> Repo.update!()
  end

  def default_content(%{email: email}, %Script{
        filename: filename,
        inserted_at: inserted_at,
        subsystem: "discord"
      }) do
    """
    -- Filename: #{filename}
    -- Creator: #{email}
    -- Created: #{inserted_at}

    -- Create a client connection
    client = discord.Client()

    -- 'ready' event will be emitted when the script is loaded
    client:on('ready', function()
      -- client.user is the path for your bot
      print('Script started as '.. client.user.username)
    end)

    -- 'messageCreate' callback will be called every time a message is sent
    client:on('messageCreate', function(message)
      -- handle messages here
    end)

    return client
    """
  end
end
