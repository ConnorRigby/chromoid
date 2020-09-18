defmodule Chromoid.DeviceChannel do
  use GenServer
  require Logger

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
    uid = System.unique_integer([:positive])

    case Channel.join(@socket, "#{@topic}:#{uid}") do
      {:ok, response, channel} ->
        Logger.info("Connected to channel: #{inspect(response)}")
        {:noreply, %{state | channel: channel, connected?: true}}

      error ->
        Logger.error("Failed to connect to channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil, connected?: false}}
    end
  end

  def handle_info(%Message{event: "photo_request"}, state) do
    {:ok, jpeg} = Chromoid.CameraProvider.Picam.jpeg()

    Channel.push(state.channel, "photo_response", %{
      content_type: "image/jpeg",
      content: Base.encode64(jpeg),
      name: "camera0-#{state.photo_index}.jpg"
    })

    {:noreply, %{state | photo_index: state.photo_index + 1}}
  end

  def handle_info(%Message{}, state) do
    {:noreply, state}
  end
end
