defmodule Freenect do
  use GenServer

  def get_next_frame(pid \\ __MODULE__) do
    GenServer.call(pid, :get_next_frame)
  end

  def set_mode(pid \\ __MODULE__, mode) do
    GenServer.call(pid, {:set_mode, mode})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    port = start_port()
    {:ok, %{port: port, caller: nil, mode: :rgb}}
  end

  def handle_info({port, {:data, jpeg}}, %{port: port} = state) do
    GenServer.reply(state.caller, {:ok, jpeg})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info(:timeout, %{caller: {_, _} = caller} = state) do
    GenServer.reply(caller, {:error, :timeout})
    {:noreply, %{state | caller: nil}}
  end

  def handle_info(unknown, state) do
    {:stop, {:unhandled_info, unknown}, state}
  end

  def handle_call(:get_next_frame, from, %{mode: :rgb} = state) do
    Port.command(state.port, <<0, 0, 0, 0, 0x0>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call(:get_next_frame, from, %{mode: :depth} = state) do
    Port.command(state.port, <<0x1, 0x1, 0x1, 0x1, 0x1>>)
    {:noreply, %{state | caller: from}, 1000}
  end

  def handle_call({:set_mode, mode}, _from, state) do
    {:reply, :ok, %{state | mode: mode}}
  end

  def start_port do
    Port.open({:spawn_executable, port_executable()}, [
      {:args, []},
      :binary,
      :exit_status,
      {:packet, 4},
      :nouse_stdio,
      {:env, [{'LD_LIBRARY_PATH', to_charlist(Application.app_dir(:freenect, ["priv", "lib"]))}]}
    ])
  end

  def port_executable(), do: Application.app_dir(:freenect, ["priv", "freenect_port"])
end
