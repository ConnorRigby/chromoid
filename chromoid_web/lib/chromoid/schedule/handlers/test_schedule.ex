defmodule Chromoid.TestSchedule do
  use Chromoid.Schedule
  require Logger

  @impl true
  def init(schedule) do
    {:ok, %{schedule: schedule}}
  end

  @impl true
  def handle_info({:trigger, schedule}, state) do
    Logger.info("#{__MODULE__} was triggered")
    {:noreply, %{state | schedule: schedule}}
  end
end
