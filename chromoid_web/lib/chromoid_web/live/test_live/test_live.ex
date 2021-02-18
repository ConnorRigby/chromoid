defmodule ChromoidWeb.TestLive do
  use ChromoidWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("inc_temperature", _value, socket) do
    IO.puts("inc_temperature")
    ChromoidWeb.Endpoint.broadcast("nx", "test", %{})
    {:noreply, socket}
  end
end
