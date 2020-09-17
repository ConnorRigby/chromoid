defmodule Chromoid.Devices.Presence do
  use Phoenix.Presence,
    otp_app: :chromoid,
    pubsub_server: Chromoid.PubSub

  def device_id_for_address(address) do
    for {id, _meta} <- Chromoid.Devices.Presence.list("devices") do
      for {addr, _} <- Chromoid.Devices.Presence.list("devices:#{id}") do
        {id, addr}
      end
    end
    |> List.flatten()
    |> Enum.find_value(fn
      {device_id, ^address} -> device_id
      _ -> false
    end)
  end

  def fetch("devices", entries) do
    for {key, entry} <- entries, into: %{}, do: {key, merge_device_metas(entry)}
  end

  def fetch("devices:" <> _device_id, entries) do
    for {key, entry} <- entries, into: %{}, do: {key, merge_ble_metas(entry)}
  end

  def fetch(_, entries), do: entries

  @allowed_fields [:online_at, :device_id, :serial, :color, :error]

  defp merge_device_metas(%{metas: metas}) do
    # The most current meta is head of the list so we
    # accumulate that first and merge everthing else into it
    Enum.reduce(metas, %{}, &Map.merge(&1, &2))
    |> Map.take(@allowed_fields)
  end

  defp merge_device_metas(unknown), do: unknown

  defp merge_ble_metas(%{metas: metas}) do
    # The most current meta is head of the list so we
    # accumulate that first and merge everthing else into it
    Enum.reduce(metas, %{}, &Map.merge(&1, &2))
    |> Map.take(@allowed_fields)
  end

  defp merge_ble_metas(unknown), do: unknown
end
