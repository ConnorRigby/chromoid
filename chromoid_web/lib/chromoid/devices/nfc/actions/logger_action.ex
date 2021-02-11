defmodule Chromoid.Devices.NFC.LoggerAction do
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
      {:name, :string, placeholder: "name of the data"},
      {:amount, :integer, placeholder: "test"}
    ]
  end
end
