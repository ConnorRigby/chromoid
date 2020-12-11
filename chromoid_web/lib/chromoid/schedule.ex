defmodule Chromoid.Schedule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "schedules" do
    belongs_to :user, Chromoid.Accounts.User
    field :crontab, Chromoid.Schedule.Chrontab
    field :handler, Chromoid.Schedule.Handler
  end
end
