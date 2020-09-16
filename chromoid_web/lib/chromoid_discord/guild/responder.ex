defmodule ChromoidDiscord.Guild.Responder do
  @moduledoc "Sends API events in response to Consumer events"
  use GenStage
  require Logger
  @api Nostrum.Api

  import ChromoidDiscord.Guild.Registry, only: [via: 2]

  @doc false
  def start_link({guild, subscribe_to}) do
    GenStage.start_link(__MODULE__, {guild, subscribe_to}, name: via(guild, __MODULE__))
  end

  @impl GenStage
  def init({guild, subscribe_to}) do
    {:consumer, %{guild: guild}, subscribe_to: subscribe_to}
  end

  @impl GenStage
  def handle_events(events, from, state) do
    for event <- events, do: handle_event(event, from)
    {:noreply, [], state}
  end

  @doc false
  def handle_event({function, args}, _from) when is_atom(function) and is_list(args) do
    apply(@api, function, args)
  catch
    error, reason ->
      args = Enum.map(args, &inspect/1) |> Enum.join(" ")

      message = [
        "Failed to execute event",
        "call: #{@api}.#{function}(#{args})\n",
        "error: ",
        "#{error} => #{inspect(reason)}\n",
        "stacktrace: \n",
        inspect(__STACKTRACE__, limit: :infinity, pretty: true)
      ]

      Logger.error(message)
  end

  def handle_event(unknown, from) do
    Logger.error("Unable to handle event: #{inspect(unknown)} from #{inspect(from)}")
  end
end
