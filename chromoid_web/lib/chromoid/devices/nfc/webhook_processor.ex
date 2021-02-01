defmodule Chromoid.Devices.NFC.WebHookProcessor do
  @moduledoc """
  Handles sending HTTP posts when RFID devices are scanned
  """

  require Logger
  use GenServer
  alias Phoenix.Socket.Broadcast
  alias Chromoid.Devices.{NFC, NFC.ISO14443a, NFC.WebHook}

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
    :ok = :hackney_pool.start_pool(:nfc_webhooks, timeout: 15000, max_connections: 100)
    :ok = @endpoint.subscribe(@nfc_topic)
    {:ok, %{}}
  end

  @impl true
  def handle_info(
        %Broadcast{topic: @nfc_topic, event: @nfc_event, payload: %{id: iso14443a_id}},
        state
      ) do
    %ISO14443a{} = nfc = NFC.get_iso14443a(iso14443a_id)
    Logger.info("Processing NFC event: #{inspect(nfc)}")

    for webhook <- NFC.load_webhooks(nfc) do
      response = WebHook.execute(webhook, nfc)
      Logger.info("Executed Webhook: #{inspect(webhook)} response: #{inspect(response)}")
    end

    {:noreply, state}
  end
end
