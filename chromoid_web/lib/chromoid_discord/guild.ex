defmodule ChromoidDiscord.Guild do
  @moduledoc """
  Root level supervisor for every guild.
  Don't start manually - The Event source should use
  the dynamic supervisor to start this supervisor.
  """
  use Supervisor

  alias ChromoidDiscord.Guild.{
    ChannelCache,
    CommandProcessor,
    DeviceStatusChannel,
    LuaConsumer
  }

  import ChromoidDiscord.Guild.Registry, only: [via: 2]

  @doc false
  def start_link({guild, config, current_user}) do
    Supervisor.start_link(__MODULE__, {guild, config, current_user})
  end

  @impl Supervisor
  def init({guild, config, current_user}) do
    children = [
      # boostrap processes
      {ChromoidDiscord.Guild.Registry, guild},
      {ChromoidDiscord.Guild.EventDispatcher, guild},

      # consumers
      {ChannelCache, {guild, config, current_user}},
      {CommandProcessor, {guild, config, current_user}},
      {DeviceStatusChannel, {guild, config, current_user}},
      {LuaConsumer, {guild, config, current_user}},

      # Responder
      {ChromoidDiscord.Guild.Responder,
       {guild, [via(guild, CommandProcessor), via(guild, DeviceStatusChannel)]}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
