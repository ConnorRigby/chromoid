defmodule ChromoidLinkOctoPrint.PluginSocket do
  use GenServer
  require Logger
  @socket_name ChromoidLinkOctoPrint.PhoenixSocket

  defmodule SocketLogger do
    @behaviour :gen_event

    @impl :gen_event
    def init(__MODULE__) do
      init({__MODULE__, []})
    end

    @spec init({module(), list()}) :: {:ok, term()} | {:error, term()}
    def init({__MODULE__, opts}) when is_list(opts) do
      env = Application.get_env(:logger, __MODULE__, [])
      opts = Keyword.merge(env, opts)
      Application.put_env(:logger, __MODULE__, opts)
      {:ok, configure(opts)}
    end

    @impl :gen_event
    def handle_call({:configure, opts}, _state) do
      env = Application.get_env(:logger, __MODULE__, [])
      opts = Keyword.merge(env, opts)
      Application.put_env(:logger, __MODULE__, opts)

      {:ok, :ok, configure(opts)}
    end

    @impl :gen_event
    def handle_event({level, _group_leader, message}, state) do
      if state.socket do
        :gen_tcp.send(state.socket, :erlang.term_to_binary({:logger, level, message}))
      end
      {:ok, state}
    end

    def handle_event(:flush, state) do
      # No flushing needed for RingLogger
      {:ok, state}
    end

    @impl :gen_event
    def handle_info(_, state) do
      # Ignore everything else since it's hard to justify RingLogger crashing
      # on a bad message.
      {:ok, state}
    end

    @impl :gen_event
    def code_change(_old_vsn, state, _extra) do
      {:ok, state}
    end

    @impl :gen_event
    def terminate(_reason, _state) do
      :ok
    end

    defp configure(opts) do
      %{socket: opts[:socket]}
    end
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    phoenix_socket_opts = Application.get_env(:chromoid_link_octo_print, :socket, [])

    {:ok, hostname} = :inet.gethostname()
    {:ok, sock} = :gen_tcp.connect(hostname, 42069, [{:active, true}, :binary, {:packet, 4}])
    Logger.add_backend(SocketLogger, [socket: sock])
    Logger.configure_backend(SocketLogger, [socket: sock])
    # send self(), :test
    {:ok, %{socket: sock, phoenix_socket_opts: phoenix_socket_opts, phoenix_socket: nil}}
  end

  def handle_info(:test, state) do
    IO.puts "idk what's going on"
    Process.send_after(self(), :test, 1500)
    {:noreply, state}
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
        :gen_tcp.send(state.socket, :erlang.term_to_binary({:url, url}))
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
