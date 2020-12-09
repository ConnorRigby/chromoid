defmodule Chromoid.RelayProvider.NotSupported do
  def set_state(_), do: {:error, "relay not supported on this device"}
end
