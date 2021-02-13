defmodule Chess.UCI do
  use GenServer
  alias Chess.UCI, as: State
  defstruct []

  def process(pid, data) do
    GenServer.call(pid, {:process, data})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def handle_call({:process, "uci"}, _from, state) do
    {:reply, ["id name cone", "id author Connor Rigby", "uciok"], state}
  end

  def handle_call({:process, "stop"}, _from, state) do
    {:reply, [], state}
  end

  def handle_call({:process, "quit"}, _from, state) do
    {:reply, [], state}
  end
  def handle_call({:process, "exit"}, _from, state) do
    {:reply, [], state}
  end
end
