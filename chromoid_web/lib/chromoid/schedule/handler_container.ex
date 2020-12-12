defmodule Chromoid.Schedule.HandlerContainer do
  use GenServer
  require Logger

  alias Chromoid.Schedule
  alias Chromoid.Schedule.HandlerContainer, as: State
  import Chromoid.Schedule.Registry, only: [via: 2]

  defstruct schedule: nil,
            handler_pid: nil,
            handler_monitor: nil,
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
        monitor = Process.monitor(pid)

        {:ok, next} = Crontab.Scheduler.get_next_run_date(state.schedule.crontab)
        trigger = Timex.diff(next, NaiveDateTime.utc_now(), :millisecond)
        timer = Process.send_after(self(), :trigger, trigger)

        Logger.info("next trigger will be: #{Timex.from_now(next)}")

        state = %{
          state
          | handler_pid: pid,
            handler_monitor: monitor,
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
        send(state.handler_pid, {:trigger, schedule})
        {:ok, next} = Crontab.Scheduler.get_next_run_date(schedule.crontab)
        trigger = Timex.diff(next, NaiveDateTime.utc_now(), :millisecond)
        timer = Process.send_after(self(), :trigger, trigger)
        Logger.info("next trigger will be: #{Timex.from_now(next)}")
        {:noreply, %{state | schedule: schedule, trigger_timer: timer}}

      {:error, changeset} ->
        Logger.error("Failed to trigger schedule in db: #{inspect(changeset)}")
        send(state.handler_pid, {:trigger, state.schedule})
        {:ok, next} = Crontab.Scheduler.get_next_run_date(state.schedule.crontab)
        trigger = Timex.diff(next, NaiveDateTime.utc_now(), :millisecond)
        timer = Process.send_after(self(), :trigger, trigger)
        Logger.info("next trigger will be: #{Timex.from_now(next)}")
        {:noreply, %{state | trigger_timer: timer}}
    end
  end
end
