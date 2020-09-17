defmodule Chromoid.Devices.Presence do
  use Phoenix.Presence,
    otp_app: :chromoid,
    pubsub_server: Chromoid.PubSub

  def fetch("devices", entries) do
    for {key, entry} <- entries, into: %{}, do: {key, merge_device_metas(entry)}
  end

  def fetch("devices:" <> _device_id, entries) do
    for {key, entry} <- entries, into: %{}, do: {key, merge_ble_metas(entry)}
  end

  def fetch(_, entries), do: entries

  @allowed_fields [:online_at, :device_id, :serial, :color]

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
