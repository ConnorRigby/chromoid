defmodule BlueHeronTransportStub do
  @moduledoc false

  use GenServer
  @behaviour BlueHeron.HCI.Transport
  alias BlueHeron.HCI.Event.{
    LEMeta.AdvertisingReport,
    LEMeta.AdvertisingReport.Device
  }

  # @hci_command_packet 0x01
  # @hci_acl_packet 0x02

  def advertise_device() do
    addr = 0x181149785464493
    serial = "H6001_1EAD"
    ble_ctx = Chromoid.BLECtx

    device = %Device{
      address: addr,
      data: ["\tMinger_" <> serial],
      event_type: nil,
      address_type: nil,
      rss: nil
    }

    send(ble_ctx, {:HCI_EVENT_PACKET, %AdvertisingReport{devices: [device]}})
  end

  defstruct recv: nil,
            init_commands: []

  @impl BlueHeron.HCI.Transport
  def init_commands(%BlueHeronTransportStub{init_commands: init_commands}),
    do: init_commands

  @impl BlueHeron.HCI.Transport
  def start_link(%BlueHeronTransportStub{} = config, recv) when is_function(recv, 1) do
    GenServer.start_link(__MODULE__, %{config | recv: recv}, name: __MODULE__)
  end

  @impl BlueHeron.HCI.Transport
  def send_command(pid, command) when is_binary(command) do
    GenServer.call(pid, {:send, :command, command})
  end

  @impl BlueHeron.HCI.Transport
  def send_acl(pid, acl) when is_binary(acl) do
    GenServer.call(pid, {:send, :acl, acl})
  end

  ## Server Callbacks

  @impl GenServer
  def init(config) do
    {:ok, config}
  end

  @impl GenServer
  def handle_call({:send, type, data}, _from, state) do
    maybe_reply(type, data, state)
    {:reply, true, state}
  end

  import Helpers

  stub_command <<0x3, 0xC, _::binary>>, "\x0e\x04\x03\x03\x0c\x00"
  stub_command <<0x1, 0x10, _::binary>>, "\x0e\x0c\x02\x01\x10\x00\x07\x0b\x00\x07\x5d\x00\x22\x88"

  stub_command <<0x14, 0xC, _::binary>>,
               "\x0e\xfc\x02\x14\x0c\x00\x52\x54\x4b\x5f\x42\x54\x5f\x34\x2e\x31" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" <>
                 "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"

  stub_command <<0x1, 0xC, _::binary>>, "\x0e\x04\x02\x01\x0c\x00"
  stub_command <<0x56, 0xC, _::binary>>, "\x0e\x04\x02\x56\x0c\x00"
  stub_command <<0x18, 0xC, _::binary>>, "\x0e\x04\x02\x18\x0c\x00"
  stub_command <<0x24, 0xC, _::binary>>, "\x0e\x04\x02\x24\x0c\x00"
  stub_command <<0x13, 0xC, _::binary>>, "\x0e\x04\x02\x13\x0c\x00"
  stub_command <<0x45, 0xC, _::binary>>, "\x0e\x04\x02\x45\x0c\x00"
  stub_command <<0x7A, 0xC, _::binary>>, "\x0e\x04\x02\x7a\x0c\x00"
  stub_command <<0x1A, 0xC, _::binary>>, "\x0e\x04\x02\x1a\x0c\x00"
  stub_command <<0x2F, 0xC, _::binary>>, "\x0e\x04\x02\x2f\x0c\x00"
  stub_command <<0x5B, 0xC, _::binary>>, "\x0e\x04\x02\x5b\x0c\x00"
  stub_command <<0x6D, 0xC, _::binary>>, "\x0e\x04\x02\x6d\x0c\x00"
  stub_command <<0x2, 0x20, _::binary>>, "\x0e\x07\x02\x02\x20\x00\x1b\x00\x10"
  stub_command <<0xF, 0x20, _::binary>>, "\x0e\x05\x02\x0f\x20\x00\x20"
  stub_command <<0x0B, 0x20, _::binary>>, "\x0e\x04\x02\x0b\x20\x00"
  stub_command <<0x0C, 0x20, _::binary>>, "\x0e\x04\x02\x0c\x20\x00"

  def maybe_reply(:command, _data, _state) do
    # raise "Unknown command: #{inspect(data, base: :hex, limit: :infinity)}"
  end

  def maybe_reply(_type, _data, _state) do
    :ok
  end
end
