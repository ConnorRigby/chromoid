defmodule ChromoidWeb.ConsoleSocket do
  require Logger
  @behaviour :cowboy_websocket

  @impl :cowboy_websocket
  def init(req, opts) do
    {:cowboy_websocket, req, opts}
  end

  @impl :cowboy_websocket
  def websocket_init(state) do
    Logger.info("Websocket init")
    ChromoidWeb.Endpoint.broadcast("scenic", "ready", %{socket: self()})

    ChromoidWeb.Endpoint.subscribe("scenic")
    # send(self(), :after_connect)
    {[], state}
  end

  @impl :cowboy_websocket
  def websocket_handle({:text, data}, state) do
    {[{:text, data}], state}
  end

  def websocket_handle({:binary, data}, state) do
    ChromoidWeb.Endpoint.broadcast("scenic", "recv", %{socket: self(), data: data})
    {[], state}
  end

  def websocket_handle(:ping, state) do
    {[:pong], state}
  end

  @impl :cowboy_websocket
  def websocket_info(:after_connect, state) do
    {[{:text, Jason.encode!(%{topic: "test_topic", event: "test_event", payload: %{}})}], state}
  end

  def websocket_info(
        %Phoenix.Socket.Broadcast{topic: "scenic", event: "send", payload: %{data: data}},
        state
      ) do
    {[{:binary, data}], state}
  end

  def websocket_info(_info, state) do
    # Logger.info("unhandled info from console socket: #{inspect(info)}")
    {[], state}
  end
end
