defmodule ChromoidWeb.ConsoleChannel do
  use ChromoidWeb, :channel
  require Logger

  @impl true
  def join("user_console", _payload, socket) do
    {:ok, tty} = ExTTY.start_link(handler: self())
    {:ok, assign(socket, :tty, tty)}
  end

  @impl true
  def terminate(_, _socket) do
    {:shutdown, :closed}
  end

  @impl true
  def handle_in("dn", %{"data" => data}, socket) do
    ExTTY.send_text(socket.assigns.tty, data)
    {:noreply, socket}
  end

  def handle_in(event, payload, socket) do
    Logger.error("Unknown console event: #{event} #{inspect(payload)}")
    {:noreply, socket}
  end

  def handle_info({:tty_data, data}, socket) do
    push(socket, "up", %{data: data})
    {:noreply, socket}
  end
end
