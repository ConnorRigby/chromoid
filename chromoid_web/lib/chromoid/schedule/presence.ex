defmodule Chromoid.Schedule.Presence do
  use Phoenix.Presence,
    otp_app: :chromoid,
    pubsub_server: Chromoid.PubSub

  def fetch("schedules", entries) do
    for {key, entry} <- entries, into: %{}, do: {key, merge_schedule_metas(entry)}
  end

  def fetch(_, entries), do: entries

  @allowed_fields [
    :last_trigger,
    :next_trigger
  ]

  defp merge_schedule_metas(%{metas: metas}) do
    # The most current meta is head of the list so we
    # accumulate that first and merge everthing else into it
    Enum.reduce(metas, %{}, &Map.merge(&1, &2))
    |> Map.take(@allowed_fields)
  end

  defp merge_schedule_metas(unknown), do: unknown
end
