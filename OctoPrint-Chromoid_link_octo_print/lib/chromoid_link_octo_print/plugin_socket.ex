defmodule ChromoidLinkOctoPrint.PluginSocket do
  use GenServer
  require Logger
  @socket_name ChromoidLinkOctoPrint.PhoenixSocket

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    phoenix_socket_opts = Application.get_env(:chromoid_link_octo_print, :socket, [])

    {:ok, hostname} = :inet.gethostname()
    {:ok, sock} = :gen_tcp.connect(hostname, 42069, [{:active, true}, :binary, {:packet, 4}])
    {:ok, %{socket: sock, phoenix_socket_opts: phoenix_socket_opts, phoenix_socket: nil}}
  end

  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    event = :erlang.binary_to_term(data)
    handle_event(event, state)
  end

  @impl GenServer
  def handle_info({PhoenixClient.Socket, socket, :connected}, %{phoenix_socket: socket} = state) do
    Logger.info("Socket connected")
    {:noreply, state}
  end

  def handle_info(
        {PhoenixClient.Socket, socket, {:disconnected, reason}},
        %{phoenix_socket: socket} = state
      ) do
    Logger.warn("Socket disconnected: #{inspect(reason)}")
    {:noreply, state}
  end

  def handle_event({:url, url}, state) do
    phoenix_socket_opts =
      Keyword.put(state.phoenix_socket_opts, :event_handler_pid, self())
      |> Keyword.put(:url, url)

    case PhoenixClient.Socket.start_link(phoenix_socket_opts, name: @socket_name) do
      {:ok, pid} ->
        Logger.info("Creating phoenix socket")
        {:noreply, %{state | phoenix_socket: pid}}

      error ->
        Logger.error("Failed to create phoenix socket: #{inspect(error)}")
        {:noreply, state}
    end
  end

  def handle_event(event, state) do
    IO.inspect(event, label: "unhandled event")
    {:noreply, state}
  end
end
