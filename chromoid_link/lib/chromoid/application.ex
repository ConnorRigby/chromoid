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
      [
        Chromoid.BLEConnection.Registry,
        Chromoid.BLEConnectionSupervisor,
        Chromoid.BLECtx,
        {PhoenixClient.Socket, {socket_opts, name: Chromoid.Socket}},
        Chromoid.DeviceChannel
        # Children for all targets
        # Starts a worker by calling: Chromoid.Worker.start_link(arg)
        # {Chromoid.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Chromoid.Worker.start_link(arg)
      # {Chromoid.Worker, arg},
    ]
  end

  def children(:rpi0) do
    [
      Picam.Camera
      # Children for all targets except host
      # Starts a worker by calling: Chromoid.Worker.start_link(arg)
      # {Chromoid.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:chromoid, :target)
  end
end
