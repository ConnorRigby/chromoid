defmodule Chromoid.Repo.Migrations.CreateSchedules do
  use Ecto.Migration

  def change do
    create table(:schedules) do
      add :user_id, references(:users), null: false
      add :crontab, :string, null: false
      add :handler, :string, null: false
      add :active, :boolean, default: false
      add :last_checkup, :utc_datetime
      timestamps()
    end

    create index(:schedules, [:user_id])
  end
end
