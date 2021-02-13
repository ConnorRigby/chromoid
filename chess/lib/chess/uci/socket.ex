defmodule Chess.UCI.Socket do
  use GenServer

  defmodule State do
    defstruct [
      :port,
      :socket,
      :client,
      :uci
    ]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    send(self(), :listen)
    {:ok, uci} = Chess.UCI.start_link(args)
    {:ok, %State{port: 4269, uci: uci}}
  end

  @impl GenServer
  def handle_info(:listen, state) do
    {:ok, socket} =
      :gen_tcp.listen(state.port, [:binary, packet: :line, active: true, reuseaddr: true])

    send(self(), :accept)
    {:noreply, %State{state | socket: socket}}
  end

  def handle_info(:accept, state) do
    {:ok, client} = :gen_tcp.accept(state.socket)
    IO.puts "accepted"
    {:noreply, %State{state | client: client}}
  end

  def handle_info({:tcp, _client, message}, state) do
    IO.inspect(message, label: "UCI message")
    messages = Chess.UCI.process(state.uci, String.trim(message))
    for message <- messages do
      :gen_tcp.send(state.client, message <> "\n")
    end
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _client}, state) do
    IO.puts "closed"
    send self(), :accept
    {:noreply, state}
  end

  def handle_info(unknown, state) do
    IO.inspect(unknown, label: "????")
    {:noreply, state}
  end
end
