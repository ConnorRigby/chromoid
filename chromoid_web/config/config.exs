# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :chromoid,
  ecto_repos: [Chromoid.Repo]

# Configures the endpoint
config :chromoid, ChromoidWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "H+QAcy4Ig4TMY9Lj7YdfxKEQTJMVz3cpT3hPg8qjpLNtAJBw56Ft8qTLAk6tFagQ",
  render_errors: [view: ChromoidWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Chromoid.PubSub,
  live_view: [signing_salt: "yuoSPch1"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

if discord_token = System.get_env("DISCORD_TOKEN") do
  config :nostrum, token: discord_token
end

if discord_client_id = System.get_env("DISCORD_CLIENT_ID") do
  config :nostrum, client_id: discord_client_id
end

if discord_client_secret = System.get_env("DISCORD_CLIENT_SECRET") do
  config :nostrum, client_secret: discord_client_secret
end

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
