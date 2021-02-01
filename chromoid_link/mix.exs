defmodule Chromoid.MixProject do
  use Mix.Project

  @app :chromoid
  @version "0.1.0"
  @all_targets [
    :ble_link_rpi0,
    :kinect_link_rpi3,
    :relay_link_rpi0,
    :relay_link_rpi3,
    :nfc_link_rpi0
  ]

  if Mix.target() != :host and Mix.target() not in @all_targets do
    Mix.raise("are you trying to do right now anyway: #{Mix.target()}")
  end

  def project do
    [
      app: @app,
      version: @version,
      name: "chromoid_link",
      elixir: "~> 1.9",
      archives: [nerves_bootstrap: "~> 1.8"],
      start_permanent: Mix.env() == :prod,
      build_embedded: false,
      aliases: [loadconfig: [&bootstrap/1]],
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Starting nerves_bootstrap adds the required aliases to Mix.Project.config()
  # Aliases are only added if MIX_TARGET is set.
  def bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Chromoid.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets, :crypto, :ssl, :public_key, :asn1]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.6.0", runtime: false},
      {:shoehorn, "~> 0.6"},
      {:ring_logger, "~> 0.6"},
      {:toolshed, "~> 0.2"},
      # {:phoenix_client, "~> 0.11.1"},
      {:phoenix_client, path: "../phoenix_client", override: true},
      {:jason, "~> 1.2"},
      {:blue_heron, path: "../blue_heron", override: true},
      {:blue_heron_transport_usb, "~> 0.1", targets: :host},
      {:blue_heron_transport_uart, "0.1.1"},
      {:cubdb, "~> 1.0.0-rc.5"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.6", targets: @all_targets},
      {:nerves_pack, "~> 0.2", targets: @all_targets},
      {:nerves_hub_cli, "~> 0.10", runtime: false},
      {:nerves_hub_link, "~> 0.9", targets: @all_targets},
      {:nerves_time, "~> 0.2", targets: @all_targets},
      {:vintage_net_wizard, "~> 0.4.0", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_rpi0, "~> 1.12", runtime: false, targets: [:ble_link_rpi0, :relay_link_rpi0, :nfc_link_rpi0]},
      {:nerves_system_rpi3, "~> 1.12", runtime: false, targets: [:kinect_link_rpi3, :relay_link_rpi3]},
      {:picam, "~> 0.4.1", targets: @all_targets},
      {:freenect, path: "../freenect", targets: [:kinect_link_rpi3]},
      {:circuits_gpio, "~> 0.4.6", targets: @all_targets},
      {:circuits_uart, "~> 1.4"},
      {:nfc, path: "../nfc", targets: [:host, :nfc_link_rpi0]}
    ]
  end

  def release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: false
    ]
  end
end
