defmodule Chromoid.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chromoid.Supervisor]

    children =
      [Chromoid.Config] ++
        children(target()) ++
        [
          Chromoid.SocketMonitor,
          Chromoid.DeviceChannel
        ]

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      Chromoid.RelayChannel,
      Chromoid.NFCChannel
    ]
  end

  def children(:freenect_link_rpi3) do
    [
      Freenect
    ]
  end

  def children(:rpi0) do
    [
      Chromoid.ConfigWizard,
      Chromoid.BLEConnection.Registry,
      Chromoid.BLEConnectionSupervisor,
      Chromoid.BLECtx,
      Picam.Camera
    ]
  end

  def children(:ble_link_rpi0) do
    [
      Chromoid.ConfigWizard,
      Chromoid.BLEConnection.Registry,
      Chromoid.BLEConnectionSupervisor,
      Chromoid.BLECtx,
      Picam.Camera
    ]
  end

  def children(:relay_link_rpi0) do
    [
      Chromoid.ConfigWizard,
      Picam.Camera,
      Chromoid.RelayProvider.Circuits
    ]
  end

  def children(:relay_link_rpi3) do
    [
      Chromoid.ConfigWizard,
      Chromoid.RelayProvider.Circuits,
      Picam.Camera,
      Chromoid.RelayChannel
    ]
  end

  def children(:nfc_link_rpi0) do
    [
      Chromoid.ConfigWizard,
      Picam.Camera,
      Chromoid.NFCChannel
    ]
  end

  def target() do
    Application.get_env(:chromoid, :target) || raise "Unconfigured target not good"
  end
end
