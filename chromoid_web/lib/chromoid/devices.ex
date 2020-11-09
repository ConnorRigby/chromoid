defmodule Chromoid.Devices do
  @moduledoc """
  Interface for working with Device records
  """
  alias Chromoid.Repo
  alias Chromoid.Devices.{Device, DeviceToken, GuildDevice}
  alias ChromoidDiscord.Guild
  import Ecto.Query

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

  def get_device(id) do
    Repo.get_by(Device, id: id)
  end

  def set_nickname(%Guild.Config{} = guild_config, %Device{} = device, nickname) do
    get_guild_device(guild_config, device)
    |> GuildDevice.changeset(%{nickname: nickname})
    |> Repo.insert_or_update()
  end

  def get_nickname(%Guild.Config{} = guild_config, %Device{} = device) do
    get_guild_device(guild_config, device)
    |> Map.fetch!(:nickname)
  end

  def find_device_by_nickname(%Guild.Config{id: guild_config_id}, nickname) do
    query =
      from gd in GuildDevice,
        where: gd.guild_config_id == ^guild_config_id and like(gd.nickname, ^nickname),
        select: gd.device_id

    case Repo.all(query) do
      nil ->
        nil

      [] ->
        nil

      [id] ->
        Repo.get!(Device, id)

      [_ | _] ->
        nil
    end
  end

  def get_guild_device(
        %Guild.Config{} = %{id: guild_config_id} = guild_config,
        %Device{} = %{id: device_id, serial: serial} = device
      ) do
    case Repo.one(
           from gd in GuildDevice,
             where: gd.guild_config_id == ^guild_config_id and gd.device_id == ^device_id,
             preload: [:device, :guild_config]
         ) do
      %GuildDevice{} = guild_device ->
        guild_device

      nil ->
        Ecto.build_assoc(device, :guild_devices,
          device_id: device.id,
          guild_config_id: guild_config.id
        )
        |> GuildDevice.changeset(%{nickname: serial})
        |> Repo.insert!()
        |> Repo.preload([:device, :guild_config])
    end
  end
end
