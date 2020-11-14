defmodule Chromoid.RelayProvider.Circuits do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def set_state("on"), do: GenServer.call(__MODULE__, {:set_state, 1})
  def set_state("off"), do: GenServer.call(__MODULE__, {:set_state, 0})
  def set_state(unknown), do: {:error, "unknown state: #{unknown}"}

  def init(_args) do
    case Circuits.GPIO.open(23, :output, initial_value: 0) do
      {:ok, ref} ->
        {:ok, %{ref: ref, state: 0}}

      error ->
        {:stop, error}
    end
  end

  def handle_call({:set_state, value}, _from, state) do
    case Circuits.GPIO.write(state.ref, value) do
      :ok ->
        {:reply, :ok, %{state | state: value}}

      error ->
        {:reply, error, state}
    end
  end
end
