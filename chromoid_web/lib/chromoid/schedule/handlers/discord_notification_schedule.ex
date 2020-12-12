defmodule Chromoid.DiscordNotificationSchedule do
  use Chromoid.Schedule
  require Logger

  @message """
  What'cha doin? Should probably check up on work....
  https://trello.com/b/5sa68gTk/company
  """

  @impl true
  def init(schedule) do
    {:ok, %{schedule: schedule}}
  end

  @impl true
  def handle_info({:trigger, schedule}, state) do
    Logger.info("#{__MODULE__} was triggered")

    case Nostrum.Api.create_dm(316_741_621_498_511_363) do
      {:ok, channel} ->
        Nostrum.Api.create_message(channel.id, @message)

      error ->
        Logger.error("Failed to create dm channel: #{inspect(error)}")
    end

    {:noreply, %{state | schedule: schedule}}
  end
end
