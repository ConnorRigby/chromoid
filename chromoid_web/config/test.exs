use Mix.Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :chromoid, Chromoid.Repo,
  username: "postgres",
  password: "postgres",
  database: "chromoid_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :chromoid, ChromoidWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :chromoid, Chromoid.Lua.ScriptStorage, root_dir: "./lua_scripts"
config :chromoid, ChromoidDiscord.OAuth, url: "http://localhost:4000/discord/oauth"
config :chromoid, ChromoidDiscord.Guild.Responder, api: ChromoidDiscord.FakeAPI
config :chromoid, ChromoidDiscord.Supervisor, dispatch_source: ChromoidDiscord.FakeDiscordSource
