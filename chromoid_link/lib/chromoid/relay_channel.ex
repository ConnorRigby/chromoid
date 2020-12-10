defmodule Chromoid.RelayChannel do
  use GenServer
  require Logger

  alias Chromoid.Config
  alias PhoenixClient.{Channel, Message}

  @socket Chromoid.Socket
  @topic "relay"
  @address 0

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    send(self(), :join_channel)
    send(self(), :reset_relay_states)
    {:ok, %{channel: nil, connected?: false, address: @address, current: "off"}}
  end

  @impl GenServer
  def handle_info(:join_channel, %{channel: nil} = state) do
    case Channel.join(@socket, @topic <> ":" <> "#{state.address}") do
      {:ok, response, channel} ->
        Logger.info("Connected to relay channel: #{inspect(response)}")
        true = Process.link(channel)
        state = %{state | channel: channel, connected?: true}
        broadcast_relay_state(state)
        {:noreply, state}

      error ->
        Logger.error("Failed to connect to relay channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil, connected?: false}}
    end
  end

  def handle_info(:reset_relay_states, state) do
    case Config.load_relay_state(state.address) do
      %{state: relay_state} ->
        provider = Application.get_env(:chromoid, :relay_provider)
        provider.set_state(relay_state)

      _ ->
        :noop
    end

    {:noreply, state}
  end

  def handle_info({Channel, channel, {:disconnected, reason}}, %{channel: channel} = state) do
    Logger.error("Relay channel disconnected: #{inspect(reason)}")
    Channel.leave(channel)
    send(self(), :join_channel)
    {:noreply, %{state | channel: nil}}
  end

  def handle_info(%Message{event: "relay_status", payload: %{"state" => relay_state}}, state) do
    Logger.info("changing relay state: #{state.current} => #{relay_state}")
    provider = Application.get_env(:chromoid, :relay_provider)

    case provider.set_state(relay_state) do
      :ok ->
        payload = %{
          state: relay_state,
          at: DateTime.utc_now() |> to_string()
        }

        Config.persist_relay_state(state.address, payload)
        Channel.push_async(state.channel, "relay_status", payload)
        {:noreply, %{state | current: relay_state}}

      {:error, _} ->
        Channel.push_async(state.channel, "relay_status", %{
          state: "error",
          at: DateTime.utc_now() |> to_string()
        })

        {:noreply, %{state | current: "error"}}
    end
  end

  def handle_info(%Message{} = message, state) do
    Logger.info("unhandled message: #{inspect(message)}")
    {:noreply, state}
  end

  defp broadcast_relay_state(state) do
    case Config.load_relay_state(state.address) do
      nil ->
        Channel.push_async(state.channel, "relay_status", %{state: state.current, at: DateTime.utc_now() |> to_string()})

      payload ->
        Channel.push_async(state.channel, "relay_status", payload)
    end
  end
end
