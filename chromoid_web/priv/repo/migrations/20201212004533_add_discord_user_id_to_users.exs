defmodule Chromoid.Repo.Migrations.AddDiscordUserIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :discord_user_id, :string
    end
  end
end
