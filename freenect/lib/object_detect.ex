defmodule ObjectDetect do
  use GenServer
  require Logger
  @external_resource "priv/python_src/ObjectDetect.py"
  @external_resource "priv/python_src/ErlCmd.py"

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def get_next_frame(pid \\ __MODULE__) do
    GenServer.call(pid, :get_next_frame)
  end

  def init(_args) do
    send self(), :open_port
    send self(), :open_freenect
    {:ok, %{port: nil, freenect: nil, jpeg: nil}}
  end
  def handle_call(:get_next_frame, _from, state) do
    {:reply, {:ok, state.jpeg}, state}
  end

  def handle_info(:open_port, state) do
    port = open_port(state)
    {:noreply, %{state | port: port}}
  end

  def handle_info(:open_freenect, state) do
    # args = [buffer_rgb_pid: self()]
    args = []
    case Freenect.start_link(args) do
      {:ok, pid} ->
        Process.send_after self(), :get_buffer_rgb, 3000
        {:noreply, %{state | freenect: pid}}
      error ->
        Logger.error "Could not open Freenect camera: #{inspect(error)}"
        {:noreply, state}
    end
  end

  def handle_info({pid, {:buffer_rgb, rgb}}, %{freenect: pid} = state) do
    true = Port.command(state.port, :erlang.term_to_binary({:buffer_depth, rgb}))
    {:noreply, state}
  end

  def handle_info(:get_buffer_rgb, state) do
    {:ok, rgb} = Freenect.get_buffer_rgb(state.freenect)
    {:ok, depth} = Freenect.get_buffer_depth(state.freenect)

    true = Port.command(state.port, :erlang.term_to_binary({:buffer_both, rgb, depth}))
    {:noreply, state}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    jpeg = :erlang.binary_to_term(data)
    Process.send_after(self(), :get_buffer_rgb, 33)
    {:noreply, %{state | jpeg: jpeg}}
  end

  def open_port(_state) do
    exe = System.find_executable("python3")
    script_dir = Application.app_dir(:freenect, ["priv", "python_src"])
    script_file = Application.app_dir(:freenect, ["priv", "python_src", "ObjectDetect.py"])

    opts = [
      {:args, ["-u", script_file]},
      {:env, []},
      {:packet, 4},
      {:cd, script_dir},
      :exit_status,
      :nouse_stdio,
      :binary
    ]
    Port.open({:spawn_executable, exe}, opts)
  end
end
