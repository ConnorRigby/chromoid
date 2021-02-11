defmodule Chromoid.Devices.NFC.Action do
  use Ecto.Schema
  import Ecto.Changeset
  alias Chromoid.Devices.NFC.{ISO14443a, Action}

  schema "nfc_actions" do
    belongs_to :nfc_iso14443a, ISO14443a
    field :module, Action.Name, null: false
    field :args, :map, null: false, default: %{}
    timestamps()
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, [:module, :args])
    |> validate_args(attrs)
    |> validate_required([:module, :args])
  end

  def validate_args(%Ecto.Changeset{valid?: false} = changeset, _attrs), do: changeset

  def validate_args(%Ecto.Changeset{} = changeset, attrs) do
    if module = get_field(changeset, :module) do
      Enum.reduce(module.fields, changeset, fn
        {name, type, _}, changeset ->
          args = get_field(changeset, :args, %{})

          case Ecto.Type.cast(type, attrs[name] || attrs["#{name}"]) do
            {:ok, ""} ->
              add_error(changeset, name, "is required")

            {:ok, value} ->
              put_change(changeset, :args, Map.put(args, name, value))

            :error ->
              add_error(changeset, name, "is invalid")
          end
      end)
    else
      changeset
    end
  end

  @type t :: %Action{
          nfc_iso14443a: ISO14443a.t(),
          args: map()
        }

  @callback perform(t()) :: :ok | {:error, String.t()}

  @callback fields :: [{name :: atom, type :: atom(), Keyword.t()}]

  @doc """
  Dipatch function
  """
  def perform(%Action{module: module, nfc_iso14443a: %ISO14443a{}} = action) do
    apply(module, :perform, [action])
  end
end
