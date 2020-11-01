defmodule ChromoidDiscord.Guild.ChannelCache do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.{EventDispatcher, Responder}

  def get_channel!(guild, id) do
    GenServer.call(via(guild, __MODULE__), {:get_channel!, id})
  end

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    {:producer_consumer,
     %{guild: guild, current_user: current_user, config: config, channels: %{}},
     subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    channels =
      Enum.reduce(events, state.channels, fn
        {:CHANNEL_CREATE, channel}, channels ->
          Map.put(channels, channel.id, channel)

        {:CHANNEL_UPDATE, {_old, new}}, channels ->
          Map.put(channels, new.id, new)

        {:CHANNEL_DELETE, channel}, channels ->
          Map.delete(channels, channel.id)

        _, channels ->
          channels
      end)

    {:noreply, [], %{state | channels: channels}}
  end

  @impl GenStage
  def handle_call({:get_channel!, id}, _from, state) do
    channel = state.channels[id] || Responder.execute_action(state.guild, {:get_channel!, [id]})
    {:reply, channel, [], %{state | channels: Map.put(state.channels, id, channel)}}
  end
end
