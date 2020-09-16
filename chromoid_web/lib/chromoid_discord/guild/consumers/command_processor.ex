defmodule ChromoidDiscord.Guild.CommandProcessor do
  @moduledoc """
  Processes commands from users
  """

  use GenStage
  require Logger
  import ChromoidDiscord.Guild.Registry, only: [via: 2]
  alias ChromoidDiscord.Guild.EventDispatcher

  @doc false
  def start_link({guild, config, current_user}) do
    GenStage.start_link(__MODULE__, {guild, config, current_user}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, config, current_user}) do
    {:consumer, %{guild: guild, current_user: current_user, config: config},
     subscribe_to: [via(guild, EventDispatcher)]}
  end

  @impl GenStage
  def handle_events(events, _from, %{current_user: %{id: current_user_id}} = state) do
    state =
      Enum.reduce(events, state, fn
        # Ignore messages from self
        {:MESSAGE_CREATE, %{author: %{id: author_id}}}, state when author_id == current_user_id ->
          state

        {:MESSAGE_CREATE, message}, state ->
          handle_message(message, state)

        _, state ->
          state
      end)

    {:noreply, [], state}
  end

  @doc false
  def handle_message(message, state) do
    IO.inspect(message, label: "IMPLEMENT ME")
    state
  end
end
