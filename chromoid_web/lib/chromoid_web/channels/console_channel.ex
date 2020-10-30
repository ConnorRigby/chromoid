defmodule ChromoidWeb.ConsoleChannel do
  use ChromoidWeb, :channel
  require Logger

  def test do
    IO.puts("""
    Welcome to the Interactive Lua Scripting Shell
    Errors will be printed here
    """)

    :ok
  end

  @impl true
  def join("user_console", %{"location" => %{"pathname" => pathname}}, socket) do
    ["/", "scripts", id | _] = Path.split(pathname)
    id = String.to_integer(id)
    {:ok, tty} = ExTTY.start_link(handler: self(), shell_opts: [[], {__MODULE__, :test, []}])

    for {_guild_id, guild} <- ChromoidDiscord.GuildCache.list_guilds() do
      ChromoidDiscord.Guild.LuaConsumer.subcribe_script(guild, id, self())
    end

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
