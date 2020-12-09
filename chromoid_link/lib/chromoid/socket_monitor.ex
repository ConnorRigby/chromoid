defmodule Chromoid.SocketMonitor do
  use GenServer
  require Logger
  alias Chromoid.Config
  @socket_name Chromoid.Socket

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    url = Chromoid.Config.get_socket_url()
    socket_opts = Application.get_env(:chromoid, :socket, [])
    socket_opts = Keyword.put(socket_opts, :event_handler_pid, self())
    socket_opts = Keyword.put(socket_opts, :url, url)
    Logger.info("Starting Phoenix Socket #{inspect(socket_opts)}")
    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts, name: @socket_name)
    {:ok, %{socket: socket}}
  end

  @impl GenServer
  def handle_info({PhoenixClient.Socket, socket, :connected}, %{socket: socket} = state) do
    Logger.info("Socket connected")
    validate_fw()
    {:noreply, state}
  end

  def handle_info(
        {PhoenixClient.Socket, socket, {:disconnected, reason}},
        %{socket: socket} = state
      ) do
    Logger.warn("Socket disconnected: #{inspect(reason)}")
    {:noreply, state}
  end

  if Application.get_env(:chromoid, :target) != :host do
    def validate_fw do
      Nerves.Runtime.validate_firmware()
    end
  else
    def validate_fw do
      :ok
    end
  end
end
