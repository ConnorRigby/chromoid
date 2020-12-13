defmodule Chromoid.Schedule.HandlerContainer do
  @moduledoc """
  Single process assosiated with a `Schedule`.
  Starts the schedule's `handler` and monitors it for
  crashes.
  """

  use GenServer
  require Logger

  alias Chromoid.Schedule
  alias Chromoid.Schedule.Presence
  alias Chromoid.Schedule.HandlerContainer, as: State
  import Chromoid.Schedule.Registry, only: [via: 2]

  defstruct schedule: nil,
            handler_pid: nil,
            trigger_timer: nil

  def start_link(schedule) do
    GenServer.start_link(__MODULE__, schedule, name: via(schedule, __MODULE__))
  end

  def init(%Schedule{} = schedule) do
    Logger.info("Launching container: #{inspect(schedule)}")
    send(self(), :start_handler)
    {:ok, %State{schedule: schedule}}
  end

  def handle_info(:start_handler, state) do
    case state.schedule.handler.start_link(state.schedule) do
      {:ok, pid} ->
        {:ok, next} = Crontab.Scheduler.get_next_run_date(state.schedule.crontab)
        trigger = Timex.diff(next, NaiveDateTime.utc_now(), :millisecond)
        timer = Process.send_after(self(), :trigger, trigger)

        Logger.info("next trigger will be: #{Timex.from_now(next)}")

        {:ok, _} =
          Presence.track(self(), "schedules", "#{state.schedule.id}", %{
            last_trigger: nil,
            next_trigger: next
          })

        state = %{
          state
          | handler_pid: pid,
            trigger_timer: timer
        }

        {:noreply, state}

      {:error, {:already_started, _pid}} ->
        # don't know what to do w/ this eitherr
        {:noreply, state}

      error ->
        Logger.error("Failed to start handler: #{state.schedule.handler}: #{inspect(error)}")
        {:noreply, state}
    end
  end

  def handle_info(:trigger, state) do
    case Schedule.trigger(state.schedule) do
      {:ok, schedule} ->
        Logger.info("Schedule triggered: #{inspect(schedule)}")
        state = schedule_next_trigger(schedule, state)
        {:noreply, state}

      {:error, changeset} ->
        Logger.error("Failed to trigger schedule in db: #{inspect(changeset)}")
        state = schedule_next_trigger(state.schedule, state)
        {:noreply, state}
    end
  end

  defp schedule_next_trigger(schedule, state) do
    send(state.handler_pid, {:trigger, schedule})
    {:ok, next} = Crontab.Scheduler.get_next_run_date(schedule.crontab)
    trigger = Timex.diff(next, NaiveDateTime.utc_now(), :millisecond)
    timer = Process.send_after(self(), :trigger, trigger)

    Presence.update(self(), "schedules", "#{state.schedule.id}", fn old ->
      %{old | last_trigger: NaiveDateTime.utc_now(), next_trigger: next}
    end)

    Logger.info("next trigger will be: #{Timex.from_now(next)}")
    %{state | schedule: schedule, trigger_timer: timer}
  end
end
