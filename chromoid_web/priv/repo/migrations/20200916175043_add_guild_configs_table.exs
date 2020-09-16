defmodule Chromoid.Repo.Migrations.AddGuildConfigsTable do
  use Ecto.Migration

  def change do
    create table(:guild_configs) do
      add :guild_id, :string
      add :device_status_channel_id, :string
    end
  end
end
