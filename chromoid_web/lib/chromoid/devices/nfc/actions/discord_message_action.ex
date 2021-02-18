defmodule Chromoid.Devices.NFC.DiscordMessageAction do
  @moduledoc """
  sends a message to discord
  """

  require Logger
  alias Chromoid.Devices.NFC.Action
  # import Chromoid.Devices.Ble.Utils
  @behaviour Action

  @impl Action
  def perform(
        %Action{
          args: %{
            "guild_id" => guild_id,
            "channel_id" => channel_id,
            "message_template" => message
          }
        } = _action
      ) do
    with {:ok, guild, channel, user} <- load(guild_id, channel_id) do
      # Mustache.render(message, )
    end
  end

  @impl Action
  def fields,
    do: [
      {:discord_guild_id, :string, [prefix: "Discord Guild ID"]},
      {:discord_channel_id, :string, [prefix: "Discord Channel ID"]},
      {:message_template, :string, [prefix: "Hello, <%= mention() %>"]}
    ]

  @spec load(String.t(), String.t()) ::
          {:ok, Nostrum.Struct.Guild.t(), Nostrum.Struct.Channel.t(), Nostrum.Struct.User.t()}
          | {:error, String.t()}
  def load(guild_id, channel_id) do
    with {:ok, guild_id} <- Snowflake.cast(guild_id),
         {:ok, channel_id} <- Snowflake.cast(channel_id),
         {:ok, guild} <- lookup_guild(guild_id),
         {:ok, channel} <- lookup_channel(guild, channel_id),
         {:ok, user} <- lookup_user(guild) do
      {:ok, guild, channel, user}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, "invalid snowflake"}
    end
  end

  @spec lookup_guild(non_neg_integer()) ::
          {:ok, Nostrum.Struct.Guild.t()} | {:error, String.t()}
  def lookup_guild(guild_id) do
    guild =
      ChromoidDiscord.GuildCache.list_guilds()
      |> Enum.find_value(fn
        {^guild_id, guild} -> guild
        {_, _} -> false
      end)

    if guild, do: {:ok, guild}, else: {:error, "guild not found"}
  end

  @spec lookup_channel(Nostrum.Struct.Guild.t(), non_neg_integer()) ::
          {:ok, Nostrum.Struct.Channel.t()} | {:error, String.t()}
  def lookup_channel(%Nostrum.Struct.Guild{} = guild, channel_id) do
    case ChromoidDiscord.Guild.ChannelCache.get_channel!(guild, channel_id) do
      %Nostrum.Struct.Channel{} = channel -> {:ok, channel}
      _ -> {:error, "channel not found"}
    end
  end

  @spec lookup_user(Nostrum.Struct.Guild.t()) ::
          {:ok, Nostrum.Struct.User.t()} | {:error, String.t()}
  def lookup_user(%Nostrum.Struct.Guild{} = guild) do
    case ChromoidDiscord.Guild.Responder.execute_action(guild, {:get_current_user, []}) do
      {:ok, user} -> {:ok, user}
      _ -> {:error, "user not found"}
    end
  end
end
