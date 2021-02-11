defmodule Chromoid.Devices.NFC.ActionProcessor do
  @moduledoc """
  Handles processing actions for NFC reads
  """

  require Logger
  use GenServer
  alias Phoenix.Socket.Broadcast
  alias Chromoid.Devices.{NFC, NFC.ISO14443a, NFC.Action}

  @endpoint ChromoidWeb.Endpoint
  @nfc_topic "nfc"
  @nfc_event "iso14443a"

  def test_broadcast(nfc) do
    @endpoint.broadcast("nfc", "iso14443a", nfc)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    :ok = @endpoint.subscribe(@nfc_topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info(
        %Broadcast{topic: @nfc_topic, event: @nfc_event, payload: %{id: iso14443a_id}},
        state
      ) do
    %ISO14443a{} = nfc = NFC.get_iso14443a(iso14443a_id)
    Logger.info("Processing NFC action: #{inspect(nfc)}")

    for action <- NFC.load_actions(nfc) do
      result = Action.perform(action)
      Logger.info("Executed action: #{inspect(action)} result: #{inspect(result)}")
    end

    {:noreply, state}
  end
end
