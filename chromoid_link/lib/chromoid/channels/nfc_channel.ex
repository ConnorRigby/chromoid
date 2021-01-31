defmodule Chromoid.NFCChannel do
  use GenServer
  require Logger

  alias Chromoid.Config
  alias PhoenixClient.{Channel, Message}

  @socket Chromoid.Socket
  @topic "nfc"

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    send(self(), :join_channel)
    send(self(), :start_nfc)
    {:ok, %{channel: nil, connected?: false, nfc: nil}}
  end

  @impl GenServer
  def handle_info(:join_channel, %{channel: nil} = state) do
    case Channel.join(@socket, @topic) do
      {:ok, response, channel} ->
        Logger.info("Connected to NFC channel: #{inspect(response)}")
        true = Process.link(channel)
        state = %{state | channel: channel, connected?: true}
        {:noreply, state}

      error ->
        Logger.error("Failed to connect to NFC channel: #{inspect(error)}")
        send(self(), :join_channel)
        {:noreply, %{state | channel: nil, connected?: false}}
    end
  end

  def handle_info(:start_nfc, state) do
    case NFC.Nif.open(self()) do
      {:ok, nfc} ->
        Logger.info("NFC opened")
        {:noreply, %{state | nfc: nfc}}

      {:error, reason} ->
        Logger.error("Failed too open NFC: #{inspect(reason)}")
        {:noreply, %{state | nfc: nil}}
    end
  end

  def handle_info({Channel, channel, {:disconnected, reason}}, %{channel: channel} = state) do
    Logger.error("NFC channel disconnected: #{inspect(reason)}")
    Channel.leave(channel)
    send(self(), :join_channel)
    {:noreply, %{state | channel: nil}}
  end

  def handle_info(%Message{} = message, state) do
    Logger.info("unhandled message: #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info({:iso14443a, %{abtUid: abtUid} = payload}, state) do
    Logger.info("NFC scanned: #{inspect(payload)}")

    if(state.channel) do
      _ = Channel.push_async(state.channel, "iso14443a", %{abtUid: Base.encode16(abtUid)})
    end

    {:noreply, state}
  end
end
