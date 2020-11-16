defmodule Chromoid.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chromoid.Supervisor]
    socket_opts = Application.get_env(:chromoid, :socket, [])

    children =
      children(target()) ++
        [
          {Chromoid.SocketMonitor, socket_opts},
          Chromoid.DeviceChannel
        ]

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Freenect
      # Children that only run on the host
      # Starts a worker by calling: Chromoid.Worker.start_link(arg)
      # {Chromoid.Worker, arg},
    ]
  end

  def children(:freenect_link_rpi3) do
    [
      Freenect
      # Picam.Camera
    ]
  end

  def children(:ble_link_rpi0) do
    [
      Chromoid.BLEConnection.Registry,
      Chromoid.BLEConnectionSupervisor,
      Chromoid.BLECtx,
      Picam.Camera
    ]
  end

  def children(:relay_link_rpi0) do
    [
      Picam.Camera,
      Chromoid.RelayProvider.Circuits
    ]
  end

  def children(:relay_link_rpi3) do
    [
      Chromoid.RelayProvider.Circuits,
      Picam.Camera
    ]
  end

  def target() do
    Application.get_env(:chromoid, :target)
  end
end
