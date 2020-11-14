defmodule Chromoid.SocketMonitor do
  use GenServer
  require Logger
  @socket_name Chromoid.Socket

  @doc false
  def start_link(socket_opts) do
    GenServer.start_link(__MODULE__, socket_opts, name: __MODULE__)
  end

  @impl GenServer
  def init(socket_opts) do
    socket_opts = Keyword.put(socket_opts, :event_handler_pid, self())
    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts, name: @socket_name)
    {:ok, %{socket: socket}}
  end

  @impl GenServer
  def handle_info({PhoenixClient.Socket, socket, :connected}, %{socket: socket} = state) do
    Logger.info("Socket connected")

    if Code.ensure_loaded(Nerves.Runtime) do
      Nerves.Runtime.validate_firmware()
    end

    {:noreply, state}
  end

  def handle_info(
        {PhoenixClient.Socket, socket, {:disconnected, reason}},
        %{socket: socket} = state
      ) do
    Logger.warn("Socket disconnected: #{inspect(reason)}")
    {:noreply, state}
  end
end
