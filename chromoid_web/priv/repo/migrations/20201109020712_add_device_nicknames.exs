defmodule Chromoid.Repo.Migrations.AddDeviceNicknames do
  use Ecto.Migration

  def change do
    create table(:guild_devices) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :guild_config_id, references(:guild_configs, on_delete: :delete_all), null: false
      add :nickname, :string, null: false
      timestamps()
    end

    create unique_index(:guild_devices, [:device_id, :guild_config_id])
  end
end
