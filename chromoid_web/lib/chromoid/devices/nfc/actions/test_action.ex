defmodule Chromoid.Devices.NFC.TestAction do
  @moduledoc """
  Simple playground action - doesn't have any signifigant functionality
  """

  alias Chromoid.Devices.NFC.Action
  require Logger
  @behaviour Action

  @impl Action
  def perform(%Action{} = action) do
    Logger.error("performing action!!!!!!!! #{inspect(action)}")
    :ok
  end

  @impl Action
  def fields do
    [
      {:argument, :string, placeholder: "test"},
      {:some_key, :string, placeholder: "data"}
    ]
  end
end
