defmodule Chromoid.Lua.Script do
  use Ecto.Schema
  import Ecto.Changeset, warn: false

  schema "scripts" do
    belongs_to :created_by, Chromoid.Accounts.User
    field :path, :string, null: false
    field :filename, :string, null: false
    field :subsystem, :string, null: false
    field :deleted_at, :utc_datetime
    field :active, :boolean
    field :content, :string, virtual: true
    timestamps()
  end

  def changeset(script, attrs \\ %{}) do
    script
    |> cast(attrs, [:created_by_id, :path, :filename, :subsystem, :active])
    |> validate_required([:path, :filename, :subsystem])
    |> validate_inclusion(:subsystem, ~w(discord))
    |> validate_filename()
    |> unique_constraint([:created_by_id, :filename])
  end

  def create_changeset(script, attrs \\ %{}) do
    script
    |> cast(attrs, [:filename, :subsystem])
    |> validate_required([:path, :filename, :subsystem])
    |> validate_inclusion(:subsystem, ~w(discord))
    |> validate_filename()
    |> unique_constraint([:created_by_id, :filename])
  end

  def delete_changeset(script) do
    script
    |> cast(%{deleted_at: NaiveDateTime.utc_now()}, [:deleted_at])
  end

  def activate_changeset(script, active? \\ true) do
    script
    |> cast(%{active: active?}, [:active])
  end

  def validate_filename(%Ecto.Changeset{valid?: true} = changeset) do
    if filename = get_change(changeset, :filename) do
      if Path.extname(filename) != ".lua",
        do: put_change(changeset, :filename, "#{filename}.lua"),
        else: changeset
    else
      changeset
    end
  end

  def validate_filename(changeset) do
    changeset
  end
end
