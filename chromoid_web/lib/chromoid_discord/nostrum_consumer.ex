defmodule ChromoidDiscord.NostrumConsumer do
  @moduledoc false

  use Nostrum.Consumer
  require Logger

  @doc false
  def start_link() do
    Consumer.start_link(__MODULE__)
  end

  @impl Nostrum.Consumer
  def handle_event(
        {:GUILD_UNAVAILABLE, %Nostrum.Struct.Guild.UnavailableGuild{} = unavailable, _ws_state}
      ) do
    Logger.info("GUILD_UNAVAILABLE: #{inspect(unavailable)}")
  end

  def handle_event({:GUILD_AVAILABLE, {%Nostrum.Struct.Guild{} = guild}, _ws_state}) do
    Logger.info("GUILD_AVAILABLE: #{guild.name}")
    {:ok, current_user} = Nostrum.Api.get_current_user()

    case ChromoidDiscord.GuildSupervisor.start_guild(guild, current_user) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok

      error ->
        Logger.error("Could not start guild: #{guild.name}: #{inspect(error)}")
    end
  end

  def handle_event({:READY, _ready, _ws_state}) do
    :noop
  end

  def handle_event(
        {:MESSAGE_CREATE, %Nostrum.Struct.Message{guild_id: guild_id} = message, _ws_state}
      ) do
    guild = %Nostrum.Struct.Guild{id: guild_id}
    ChromoidDiscord.Guild.EventDispatcher.dispatch(guild, {:MESSAGE_CREATE, message})
  end

  def handle_event({:PRESENCE_UPDATE, {guild_id, old, new}, _ws_state}) do
    guild = %Nostrum.Struct.Guild{id: guild_id}
    ChromoidDiscord.Guild.EventDispatcher.dispatch(guild, {:PRESENCE_UPDATE, {old, new}})
  end

  def handle_event(event) do
    Logger.error(["Unhandled event from Nostrum ", inspect(event)])
  end
end
