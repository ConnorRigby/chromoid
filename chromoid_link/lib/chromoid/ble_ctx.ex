defmodule Chromoid.BLECtx do
  use GenServer
  require Logger

  alias BlueHeron.HCI.Command.{
    ControllerAndBaseband.WriteLocalName,
    LEController.SetScanEnable
  }

  alias BlueHeron.HCI.Event.{
    LEMeta.AdvertisingReport,
    LEMeta.AdvertisingReport.Device
  }

  # Sets the name of the BLE device
  @write_local_name %WriteLocalName{name: "ChromoidLink"}

  @default_usb_config %BlueHeronTransportUSB{
    vid: 0x0BDA,
    pid: 0xB82C,
    init_commands: [@write_local_name]
  }

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    send(self(), :init_ble)
    {:ok, %{ctx: nil}}
  end

  @impl GenServer
  def handle_info(:init_ble, %{ctx: nil} = state) do
    case BlueHeron.transport(@default_usb_config) do
      {:ok, ctx} ->
        :ok = BlueHeron.add_event_handler(ctx)
        {:noreply, %{state | ctx: ctx}}

      error ->
        Logger.error("Could not start bluetooth: #{inspect(error)}")
        {:noreply, state}
    end
  end

  # Sent when a transport connection is established
  def handle_info({:BLUETOOTH_EVENT_STATE, :HCI_STATE_WORKING}, state) do
    # Enable BLE Scanning. This will deliver messages to the process mailbox
    # when other devices broadcast
    BlueHeron.hci_command(state.ctx, %SetScanEnable{le_scan_enable: true, filter_duplicates: true})

    {:noreply, state}
  end

  # Match for the Bulb.
  def handle_info(
        {:HCI_EVENT_PACKET, %AdvertisingReport{devices: devices}},
        state
      ) do
    for device <- devices do
      # IO.inspect(device, label: "device")
      maybe_connect(device, state)
    end

    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def connect(addr, serial, state) do
    IO.inspect(addr, base: :hex, label: serial)

    case Chromoid.BLEConnectionSupervisor.create_connection(
           {state.ctx, %{address: addr, serial: serial}}
         ) do
      {:ok, _pid} ->
        Logger.info("Trying to connect to Govee LED #{inspect(addr, base: :hex)}")
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.info("already connected")

        :ok

      error ->
        Logger.error("Could not connect to #{serial}: #{inspect(error)}")
    end

    state
  end

  def maybe_connect(%Device{address: addr, data: ["\tMinger_" <> serial | _]}, state) do
    connect(addr, serial, state)
  end

  def maybe_connect(%Device{address: addr, data: ["\tihoment_" <> serial | _]}, state) do
    connect(addr, serial, state)
  end

  def maybe_connect(_, state), do: state
end
