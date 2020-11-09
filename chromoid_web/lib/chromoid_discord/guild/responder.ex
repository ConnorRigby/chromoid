defmodule ChromoidDiscord.Guild.Responder do
  @moduledoc "Sends API events in response to Consumer events"
  use GenStage
  require Logger

  if Mix.env() == :prod do
    @api Nostrum.Api
  else
    @api ChromoidDiscord.FakeAPI
  end

  import ChromoidDiscord.Guild.Registry, only: [via: 2]

  @doc false
  def start_link({guild, subscribe_to}) do
    GenStage.start_link(__MODULE__, {guild, subscribe_to}, name: via(guild, __MODULE__))
  end

  def execute_action(guild, action) do
    GenServer.call(via(guild, __MODULE__), {:execute_action, action})
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

  @impl GenStage
  def handle_call({:execute_action, action}, from, state) do
    handle_events([{action, from}], nil, state)
  end

  @doc false
  def handle_event({{function, args}, caller}, from) when is_atom(function) and is_list(args) do
    reply = handle_event({function, args}, from)
    GenServer.reply(caller, reply)
    reply
  end

  def handle_event(:noop, _from) do
    :noop
  end

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
      {:error, message}
  end

  def handle_event(unknown, from) do
    Logger.error("Unable to handle event: #{inspect(unknown)} from #{inspect(from)}")
  end
end
