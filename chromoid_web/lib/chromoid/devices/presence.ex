defmodule Chromoid.Devices.Presence do
  use Phoenix.Presence,
    otp_app: :chromoid,
    pubsub_server: Chromoid.PubSub

  def device_id_for_ble_address(address) do
    for {id, _meta} <- Chromoid.Devices.Presence.list("devices") do
      for {"ble-" <> addr, _} <- Chromoid.Devices.Presence.list("devices:#{id}") do
        {id, addr}
      end
    end
    |> List.flatten()
    |> Enum.find_value(fn
      {device_id, ^address} -> device_id
      _ -> false
    end)
  end

  def list_bles(device) do
    for {"ble-" <> addr, value} <- Chromoid.Devices.Presence.list("devices:#{device.id}"),
        into: %{} do
      {addr, value}
    end
  end

  def list_relays(device) do
    for {"relay-" <> addr, value} <- Chromoid.Devices.Presence.list("devices:#{device.id}"),
        into: %{} do
      {addr, value}
    end
  end

  def fetch("devices", entries) do
    for {key, entry} <- entries, into: %{}, do: {key, merge_device_metas(entry)}
  end

  def fetch("devices:" <> _device_id, entries) do
    ble =
      for {key = "ble-" <> _addr, entry} <- entries, into: %{}, do: {key, merge_ble_metas(entry)}

    relay =
      for {key = "relay-" <> _addr, entry} <- entries,
          into: %{},
          do: {key, merge_relay_metas(entry)}

    Map.merge(ble, relay)
  end

  def fetch(_, entries), do: entries

  @allowed_fields [
    :online_at,
    :last_communication,
    :status,
    :storage,
    :path,
    :progress,
    :job
  ]

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
    |> Map.take([:device_id, :serial, :color, :error, :online_at])
  end

  defp merge_ble_metas(unknown), do: unknown

  defp merge_relay_metas(%{metas: metas}) do
    # The most current meta is head of the list so we
    # accumulate that first and merge everthing else into it
    Enum.reduce(metas, %{}, &Map.merge(&1, &2))
    |> Map.take(Map.keys(%Chromoid.Devices.RelayStatus{}))
  end

  defp merge_relay_metas(unknown), do: unknown
end
