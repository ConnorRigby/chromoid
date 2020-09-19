defmodule Chromoid.ShoehornHandler do
  require Logger
  use Shoehorn.Handler

  def application_exited(app, reason, state) do
    Logger.error("Application stopped: #{app} #{inspect(reason)}")
    Application.ensure_all_started(app)
    {:continue, state}
  end
end
