defmodule Chromoid.Schedule.Handler do
  @type schedule() :: Chromoid.Schedule.t()
  @callback start_link(schedule()) :: GenServer.on_start()

  @behaviour Ecto.Type
end
