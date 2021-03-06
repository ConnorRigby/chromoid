defmodule Chromoid.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    main_viewport_config = %{
      name: :main_viewport,
      size: {1280, 720},
      default_scene: {SpeediViewUI.Scene.Dash, nil},
      drivers: [
        %{
          module: Scenic.Driver.Nerves.NX,
          name: :nx,
          opts: [resizeable: false, title: "asdf"]
        }
      ]
    }

    children = [
      # Start the Ecto repository
      Chromoid.Repo,
      # Start the Telemetry supervisor
      ChromoidWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Chromoid.PubSub},
      # Start the Discord bot
      ChromoidDiscord.Supervisor,
      # Start the Device Name registry
      Chromoid.Devices.DeviceRegistry,
      # Start the Device BLE Supervisor
      Chromoid.Devices.BLESupervisor,
      # Start the Device Relay Supervisor
      Chromoid.Devices.RelaySupervisor,
      # Start the Device Presence
      Chromoid.Devices.Presence,
      Chromoid.Schedule.Presence,
      Chromoid.Schedule.Registry,
      # Start the schedule handler supervisor
      # Chromoid.ScheduleSupervisor,
      # Start the Runner checkup process
      # Chromoid.Schedule.Runner,
      # Start the Endpoint (http/https)
      ChromoidWeb.Endpoint,
      # Start the NFC/RFID WebHook processor
      Chromoid.Devices.NFC.WebHookProcessor,
      # Start the NFC/RFID Action processor
      Chromoid.Devices.NFC.ActionProcessor,
      {Scenic, [viewports: [main_viewport_config]]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chromoid.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ChromoidWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
