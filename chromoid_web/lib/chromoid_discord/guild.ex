defmodule ChromoidDiscord.Guild do
  @moduledoc """
  Root level supervisor for every guild.
  Don't start manually - The Event source should use
  the dynamic supervisor to start this supervisor.
  """
  use Supervisor

  @doc false
  def start_link({guild, config, current_user}) do
    Supervisor.start_link(__MODULE__, {guild, config, current_user})
  end

  @impl Supervisor
  def init({guild, config, current_user}) do
    children = [
      {ChromoidDiscord.Guild.Registry, guild},
      {ChromoidDiscord.Guild.EventDispatcher, guild},
      {ChromoidDiscord.Guild.CommandProcessor, {guild, config, current_user}},
      {ChromoidDiscord.Guild.DeviceStatusChannel, {guild, config, current_user}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
