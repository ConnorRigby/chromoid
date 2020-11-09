defmodule ChromoidLinkOctoPrint.PluginSocket do
  use GenServer
  require Logger
  alias ChromoidLinkOctoPrint.DeviceChannel
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
      content = elem(message, 1)
      if state.socket do
        :gen_tcp.send(state.socket, :erlang.term_to_binary({:logger, level, content}))
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

  def async_start(url) do
    GenServer.cast(__MODULE__, {:url, url})
  end

  @impl GenServer
  def init(_args) do
    send(self(), :plugin_connect)
    phoenix_socket_opts = Application.get_env(:chromoid_link_octo_print, :socket, [])
    {:ok, %{socket: nil, phoenix_socket_opts: phoenix_socket_opts, phoenix_socket: nil}}
  end

  @impl GenServer
  def handle_cast({:url, url}, state) do
    handle_event({:url, url}, state)
  end

  def handle_info(:plugin_connect, state) do
    {:ok, hostname} = :inet.gethostname()

    case :gen_tcp.connect(hostname, 42069, [{:active, true}, :binary, {:packet, 4}]) do
      {:ok, sock} ->
        Logger.add_backend(SocketLogger, socket: sock)
        Logger.configure_backend(SocketLogger, socket: sock)
        send(self(), :ping)
        {:noreply, %{state | socket: sock}}

      error ->
        Logger.error("Failed to connect to socket: #{inspect(error)}")
        Process.send_after(self(), :plugin_connect, 1500)
        {:noreply, state}
    end
  end

  def handle_info(:ping, state) do
    :gen_tcp.send(state.socket, :erlang.term_to_binary({:ping}))
    {:noreply, state, 6000}
  end

  def handle_info(:timeout, state) do
    Logger.error("ping failed")
    send(self(), :ping)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.remove_backend(SocketLogger)
    Logger.error("Socket disconnected")
    send(self(), :plugin_connect)
    {:noreply, %{state | socket: nil}}
  end

  def handle_info({:tcp, socket, data}, %{socket: socket} = state) do
    event =
      try do
        {:ok, :erlang.binary_to_term(data)}
      catch
        _, error ->
          {:error, "failed to decode data: #{inspect(error)}"}
      end

    case event do
      {:ok, event} ->
        handle_event(event, state)

      {:error, reason} ->
        Logger.error(reason)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({PhoenixClient.Socket, socket, :connected}, %{phoenix_socket: socket} = state) do
    Logger.info("Socket connected")
    if state.socket do
      :gen_tcp.send(state.socket, :erlang.term_to_binary({:phoenix_socket_connection, "connected"}))
    end
    {:noreply, state}
  end

  def handle_info(
        {PhoenixClient.Socket, socket, {:disconnected, reason}},
        %{phoenix_socket: socket} = state
      ) do
    Logger.warn("Socket disconnected: #{inspect(reason)}")
    if state.socket do
      :gen_tcp.send(state.socket, :erlang.term_to_binary({:phoenix_socket_connection, "disconnected"}))
    end
    {:noreply, state}
  end

  def handle_event({:url, url}, state) do
    Logger.info("Got URL from plugin")

    phoenix_socket_opts =
      Keyword.put(state.phoenix_socket_opts, :event_handler_pid, self())
      |> Keyword.put(:url, url)

    case PhoenixClient.Socket.start_link(phoenix_socket_opts, name: @socket_name) do
      {:ok, pid} ->
        Logger.info("Creating phoenix socket")
        if state.socket do
          :gen_tcp.send(state.socket, :erlang.term_to_binary({:phoenix_socket_connection, "connecting"}))
        end
        {:noreply, %{state | phoenix_socket: pid}}

      error ->
        Logger.error("Failed to create phoenix socket: #{inspect(error)}")
        {:noreply, state}
    end
  end

  def handle_event(:pong, state) do
    Logger.info("got pong")
    Process.send_after(self(), :ping, 5000)
    {:noreply, state}
  end

  def handle_event({:progress, storage, path, progress}, state) do
    DeviceChannel.progress_report(storage, path, progress)
    {:noreply, state}
  end

  def handle_event(event, state) do
    IO.inspect(event, label: "unhandled event")
    {:noreply, state}
  end
end
