defmodule ChromoidDiscord.Guild.Config do
  use Ecto.Schema
  import Ecto.Changeset

  schema "guild_configs" do
    field :guild_id, Snowflake
    field :device_status_channel_id, Snowflake
  end

  @doc false
  def changeset(guild_config, attrs \\ %{}) do
    guild_config
    |> cast(attrs, [:guild_id, :device_status_channel_id])
    |> validate_required([:guild_id])
  end
end
