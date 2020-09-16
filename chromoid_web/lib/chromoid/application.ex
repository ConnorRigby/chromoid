defmodule Chromoid.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Chromoid.Repo,
      # Start the Telemetry supervisor
      ChromoidWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Chromoid.PubSub},
      # Start the Discord bot
      ChromoidDiscord.Supervisor,
      # Start the Device Presence
      Chromoid.Devices.Presence,
      # Start the Endpoint (http/https)
      ChromoidWeb.Endpoint
      # Start a worker by calling: Chromoid.Worker.start_link(arg)
      # {Chromoid.Worker, arg}
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
