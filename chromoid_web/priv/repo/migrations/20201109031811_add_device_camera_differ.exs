defmodule Chromoid.Repo.Migrations.AddDeviceCameraDiffer do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :camera_differ_id, references(:devices, on_delete: :nilify_all)
    end
  end
end
