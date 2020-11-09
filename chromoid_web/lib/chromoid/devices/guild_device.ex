defmodule Chromoid.Devices.GuildDevice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "guild_devices" do
    belongs_to :device, Chromoid.Devices.Device
    belongs_to :guild_config, ChromoidDiscord.Guild.Config
    field :nickname, :string, null: false
    timestamps()
  end

  def changeset(guild_device, attrs \\ %{}) do
    guild_device
    |> cast(attrs, [:nickname])
    |> validate_required([:nickname])
    |> validate_change(:nickname, fn :nickname, value ->
      if Regex.match?(~r/(.*\s+.*)+/, value) do
        [nickname: "may not contain whitespace"]
      else
        []
      end
    end)
  end
end
