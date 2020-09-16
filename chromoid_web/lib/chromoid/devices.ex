defmodule Chromoid.Devices do
  @moduledoc """
  Interface for working with Device records
  """
  alias Chromoid.Repo
  alias Chromoid.Devices.DeviceToken

  @doc """
  Generate a token for a device
  """
  def generate_token(device) do
    {token, device_token} = DeviceToken.build_hashed_token(device)
    Repo.insert!(device_token)
    token
  end

  @doc """
  Gets the device with the given signed token.
  """
  def get_device_by_token(token) do
    {:ok, query} = DeviceToken.verify_token_query(token)
    Repo.one(query)
  end
end
