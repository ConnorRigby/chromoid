defmodule Chromoid.MixProject do
  use Mix.Project

  @app :chromoid

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      releases: [{@app, release()}],
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Chromoid.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  nostrum =
    if Mix.env() == :prod && System.get_env("DISCORD_TOKEN") do
      {:nostrum, github: "Kraigie/nostrum"}
    else
      {:nostrum, github: "Kraigie/nostrum", runtime: false}
    end

  @nostrum nostrum

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 2.0"},
      {:phoenix, "~> 1.5.3"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_view, "~> 0.14.7"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.2.9"},
      {:telemetry_metrics, "~> 0.5"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:cowlib, "~> 2.9", override: true},
      {:phx_gen_auth, "~> 0.5.0", runtime: false, only: :dev},
      {:ring_logger, "~> 0.8", only: :prod},
      {:phoenix_client, "~> 0.11.1", only: [:test, :dev]},
      {:exirc, "~> 2.0"},
      {:tesla, "~> 1.3.0"},
      {:timex, "~> 3.6"},
      @nostrum
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp release do
    [
      include_executables_for: [:unix],
      applications: [runtime_tools: :permanent],
      steps: [:assemble]
    ]
  end
end
