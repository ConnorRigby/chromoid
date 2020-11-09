defmodule ChromoidLinkOctoPrint.DeviceChannel do
  use GenServer
  require Logger

  alias PhoenixClient.{Channel, Message}

  @socket ChromoidLinkOctoPrint.PhoenixSocket
  @topic "device"

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def progress_report(storage, path, progress) do
    GenServer.call(__MODULE__, {:progress, storage, path, progress})
  end

  def job(data) do
    GenServer.call(__MODULE__, {:job, data})
  end

  @impl GenServer
  def init(_args) do
    send(self(), :join_channel)
    {:ok, %{channel: nil, connected?: false, photo_index: 0, last_error: nil}}
  end

  @impl GenServer
  def handle_info(:join_channel, %{channel: nil} = state) do
    # uid = System.unique_integer([:positive])
    # case Channel.join(@socket, "#{@topic}:#{uid}") do
    case Channel.join(@socket, @topic) do
      {:ok, response, channel} ->
        Logger.info("Connected to channel: #{inspect(response)}")
        true = Process.link(channel)
        {:noreply, %{state | channel: channel, connected?: true, last_error: nil}}

      error ->
        if state.last_error != error do
          Logger.error("Failed to connect to channel: #{inspect(error)}")
        end

        send(self(), :join_channel)
        {:noreply, %{state | channel: nil, connected?: false, last_error: error}}
    end
  end

  def handle_info({Channel, channel, {:disconnected, reason}}, %{channel: channel} = state) do
    Logger.error("Channel disconnected:  #{inspect(reason)}")
    Channel.leave(channel)
    send(self(), :join_channel)
    {:noreply, %{state | channel: nil}}
  end

  def handle_info(%Message{event: "photo_request"}, state) do
    Channel.push(state.channel, "photo_response", %{
      content_type: "image/jpeg",
      content: Base.encode64("fail"),
      name: "camera0-#{state.photo_index}.jpg"
    })

    {:noreply, %{state | photo_index: state.photo_index + 1}}
  end

  def handle_info(%Message{}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call({:progress, _storage, _path, _progress}, _from, %{chhannel: nil} = state) do
    Logger.error("Channel not connected. Not sending progress report")
    {:noreply, state}
  end

  def handle_call({:progress, storage, path, progress}, _from, state) do
    Logger.debug("sending progress report: #{storage} #{path} #{progress}")

    Channel.push_async(state.channel, "progress_report", %{
      storage: storage,
      path: path,
      progress: progress
    })

    {:reply, :ok, state}
  end

  def handle_call({:job, data}, _from, state) do
    Channel.push_async(state.channel, "job", data)
    {:reply, :ok, state}
  end
end
