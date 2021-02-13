defmodule Chess.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  alias Chess.UCI

  use Application

  def start(_type, _args) do
    children = [
      UCI.Socket
      # Starts a worker by calling: Chess.Worker.start_link(arg)
      # {Chess.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Chess.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
