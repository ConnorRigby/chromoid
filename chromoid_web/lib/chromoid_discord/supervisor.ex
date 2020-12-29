defmodule ChromoidDiscord.Supervisor do
  @moduledoc false
  use Supervisor

  @dispatch_source Application.get_env(:chromoid, __MODULE__)[:dispatch_source]
  @dispatch_source || Mix.raise("dispatch_source unconfigured")

  @doc false
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    children = [
      # Monitors an ETS table for guilds to save data on
      ChromoidDiscord.GuildCache,
      # dynamic supervisor for each guild the bot is in
      ChromoidDiscord.GuildSupervisor,
      # source of discord events
      @dispatch_source
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
