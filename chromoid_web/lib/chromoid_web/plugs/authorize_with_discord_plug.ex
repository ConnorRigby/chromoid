defmodule ChromoidWeb.AuthorizeWithDiscordPlug do
  def authorize_with_discord(conn, _params) do
    call(conn, [])
  end

  @behaviour Plug
  import Plug.Conn

  def init(opts) do
    {:ok, opts}
  end

  def call(conn, _opts) do
    redirect_url = ChromoidDiscord.OAuth.authorization_url()

    case get_session(conn, :current_user) do
      nil ->
        put_resp_header(conn, "location", redirect_url)
        |> send_resp(302, redirect_url)

      %{} ->
        conn
    end
  end
end
