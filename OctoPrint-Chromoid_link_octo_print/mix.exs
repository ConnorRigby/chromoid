defmodule ChromoidLinkOctoPrint.MixProject do
  use Mix.Project

  @app :chromoid_link_octo_print

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets],
      mod: {ChromoidLinkOctoPrint.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_client, path: "../phoenix_client"},
      {:jason, "~> 1.2"},
      {:bakeware, "~> 0.1.3"},
      {:ring_logger, "~> 0.8.1"},
      {:tesla, "~> 1.3"}
    ]
  end

  defp release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      steps: [:assemble, &Bakeware.assemble/1],
      strip_beams: Mix.env() == :prod
    ]
  end
end
