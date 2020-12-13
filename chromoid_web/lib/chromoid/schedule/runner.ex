defmodule Chromoid.Schedule.Runner do
  use GenServer
  alias Chromoid.Schedule
  alias Chromoid.Schedule.Runner, as: State
  alias Chromoid.ScheduleSupervisor
  require Logger

  defstruct schedules: [],
            monitors: %{}

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    Logger.info("Init Schedule runner")
    send(self(), :reindex)
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_info(:reindex, state) do
    Logger.info("Indexing schedules")
    schedules = Schedule.all()
    {:noreply, %{state | schedules: schedules}, {:continue, :reindex}}
  end

  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {schedule, state} = get_crashed_schedule(ref, pid, state)

    if schedule do
      Logger.warn("Schedule container crashed: #{inspect(schedule)}, #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_continue(:reindex, %{schedules: [schedule | rest], monitors: mons} = state) do
    Logger.info("Reindexing: #{inspect(schedule)}")

    case ScheduleSupervisor.start_child(schedule) do
      {:ok, pid} ->
        Logger.info("Started schedule")
        ref = Process.monitor(pid)

        state = %{
          state
          | schedules: rest,
            monitors: Map.put(mons, schedule.id, {ref, pid})
        }

        {:noreply, state, {:continue, :reindex}}

      {:error, {:already_started, _pid}} ->
        # not sure what to do about this yet
        state = %{state | schedules: rest}
        {:noreply, state, {:continue, :reindex}}
    end
  end

  def handle_continue(:reindex, %{schedules: []} = state) do
    {:noreply, state}
  end

  defp get_crashed_schedule(ref, pid, state) do
    schedule =
      Enum.find_value(state.monitors, fn
        {schedule_id, {^ref, ^pid}} -> Schedule.get(schedule_id)
        {_, _} -> false
      end)

    monitors =
      if schedule do
        Map.delete(state.monitors, schedule.id)
      else
        state.monitors
      end

    {schedule, %{state | monitors: monitors}}
  end
end
