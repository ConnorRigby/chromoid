defmodule Chromoid.DeviceChannel do
  use GenServer
  require Logger

  alias Chromoid.Config
  alias PhoenixClient.{Channel, Message}

  @socket Chromoid.Socket
  @topic "device"

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    send(self(), :join_channel)
    {:ok, %{channel: nil, connected?: false, photo_index: 0}}
  end

  @impl GenServer
  def handle_info(:join_channel, %{channel: nil} = state) do
    case Channel.join(@socket, @topic) do
      {:ok, response, channel} ->
        Logger.info("Connected to channel: #{inspect(response)}")
        true = Process.link(channel)
        state = %{state | channel: channel, connected?: true}
        send(self(), :token_refresh)
        {:noreply, state}

      error ->
        Logger.error("Failed to connect to channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil, connected?: false}}
    end
  end

  def handle_info(:token_refresh, state) do
    case Channel.push(state.channel, "token_refresh", %{}) do
      {:ok, %{"token" => new_token}} ->
        Config.put_token_refresh(new_token)
        {:noreply, state}

      error ->
        Logger.error("Failed to refresh token: #{inspect(error)}")
        {:noreply, state}
    end
  end

  def handle_info({Channel, channel, {:disconnected, reason}}, %{channel: channel} = state) do
    Logger.error("Channel disconnected: #{inspect(reason)}")
    Channel.leave(channel)
    send(self(), :join_channel)
    {:noreply, %{state | channel: nil}}
  end

  def handle_info(%Message{event: "photo_request"}, state) do
    provider = Application.get_env(:chromoid, :camera_provider)

    case provider.jpeg() do
      {:ok, jpeg} ->
        Channel.push(state.channel, "photo_response", %{
          content_type: "image/jpeg",
          content: Base.encode64(jpeg),
          name: "camera0-#{state.photo_index}.jpg"
        })

      error ->
        Channel.push(state.channel, "photo_response", %{
          error: inspect(error)
        })
    end

    {:noreply, %{state | photo_index: state.photo_index + 1}}
  end

  def handle_info(%Message{} = message, state) do
    Logger.info("unhandled message: #{inspect(message)}")
    {:noreply, state}
  end
end
