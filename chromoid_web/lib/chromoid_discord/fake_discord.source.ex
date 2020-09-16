defmodule ChromoidDiscord.FakeDiscordSource do
  @moduledoc """
  Stub interface for dispatching Discord events
  """

  use GenServer
  require Logger

  @doc false
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    Logger.debug("FakeDiscordSource not implemented yet.")
    {:ok, %{}}
  end
end
