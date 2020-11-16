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
    # uid = System.unique_integer([:positive])
    # case Channel.join(@socket, "#{@topic}:#{uid}") do
    case Channel.join(@socket, @topic) do
      {:ok, response, channel} ->
        Logger.info("Connected to channel: #{inspect(response)}")
        true = Process.link(channel)
        maybe_bc_relay_state(%{state | channel: channel, connected?: true})
        {:noreply, %{state | channel: channel, connected?: true}}

      error ->
        Logger.error("Failed to connect to channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil, connected?: false}}
    end
  end

  def handle_info({Channel, channel, {:disconnected, reason}}, %{channel: channel} = state) do
    Logger.error("Channel disconnected")
    Channel.leave(channel)
    send(self(), :join_channel)
    {:noreply, %{state | channel: nil}}
  end

  def handle_info(%Message{event: "photo_request"}, state) do
    # {:ok, jpeg} = Chromoid.CameraProvider.Picam.jpeg()
    {:ok, jpeg} = Chromoid.CameraProvider.Freenect.jpeg()

    Channel.push(state.channel, "photo_response", %{
      content_type: "image/jpeg",
      content: Base.encode64(jpeg),
      name: "camera0-#{state.photo_index}.jpg"
    })

    {:noreply, %{state | photo_index: state.photo_index + 1}}
  end

  def handle_info(%Message{event: "freenect", payload: %{"command" => "mode", "value" => "rgb"}}, state) do
    Logger.info("changing freenect mode => rgb")
    Freenect.set_mode(:rgb)
    {:noreply, state}
  end

  def handle_info(%Message{event: "freenect", payload: %{"command" => "mode", "value" => "depth"}}, state) do
    Logger.info("changing freenect mode => depth")
    Freenect.set_mode(:depth)
    {:noreply, state}
  end

  def handle_info(%Message{event: "relay_status", payload: %{"state" => relay_state}}, state) do
    Logger.info("changing relay state => relay_state")

    case Chromoid.RelayProvider.Circuits.set_state(relay_state) do
      :ok ->
        Channel.push_async(state.channel, "relay_status", %{
          state: relay_state,
          at: DateTime.utc_now() |> to_string()
        })

      {:error, _} ->
        Channel.push_async(state.channel, "relay_status", %{
          state: "error",
          at: DateTime.utc_now() |> to_string()
        })
    end

    {:noreply, state}
  end

  def handle_info(%Message{} = message, state) do
    Logger.info("unhandled message: #{inspect(message)}")
    {:noreply, state}
  end

  if Mix.target() == :host do
    defp maybe_bc_relay_state(state) do
      Channel.push_async(state.channel, "relay_status", %{
        state: "off",
        at: DateTime.utc_now() |> to_string()
      })
    end

    def set_relay_state(state) do
      send(__MODULE__, %Message{event: "relay_status", payload: %{"state" => state}})
    end
  else
    defp maybe_bc_relay_state(state) do
      if Process.whereis(Chromoid.RelayProvider.Circuits) do
        Channel.push_async(state.channel, "relay_status", %{
          state: "off",
          at: DateTime.utc_now() |> to_string()
        })
      end
    end
  end
end
