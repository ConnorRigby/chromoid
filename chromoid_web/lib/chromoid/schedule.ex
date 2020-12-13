defmodule Chromoid.Schedule do
  alias Chromoid.Accounts.User
  alias Chromoid.Schedule
  alias Chromoid.Schedule.{Crontab, Handler}
  alias Chromoid.Repo

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false

  schema "schedules" do
    belongs_to :user, User
    field :crontab, Crontab
    field :handler, Handler
    field :active, :boolean, default: false
    field :last_checkup, :utc_datetime
    timestamps()
  end

  def changeset(%User{} = user, params) do
    %Schedule{user_id: user.id}
    |> cast(params, [:crontab, :handler, :active])
    |> validate_required([:crontab, :handler])
  end

  def changeset(%Schedule{} = schedule, attrs) do
    schedule
    |> cast(attrs, [:last_checkup])
  end

  ### access

  def get(id) do
    Repo.get(Schedule, id)
  end

  def new_for(%User{} = user, params) do
    changeset(user, params)
    |> Repo.insert()
  end

  def trigger(%Schedule{} = schedule) do
    changeset(schedule, %{last_checkup: DateTime.utc_now()})
    |> Repo.update()
  end

  def all() do
    Repo.all(Schedule)
    |> Repo.preload([:user])
  end

  ### macros

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Chromoid.Schedule.Handler
      use GenServer
      import Chromoid.Schedule.Registry, only: [via: 2]

      def start_link(%Chromoid.Schedule{} = schedule) do
        GenServer.start_link(__MODULE__, schedule, name: via(schedule, __MODULE__))
      end
    end
  end
end
