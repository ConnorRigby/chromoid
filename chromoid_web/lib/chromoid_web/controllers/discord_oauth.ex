defmodule ChromoidWeb.DiscordOauthController do
  use ChromoidWeb, :controller
  alias ChromoidDiscord.OAuth
  require Logger

  def logout(conn, _) do
    ChromoidWeb.UserAuth.log_out_user(conn)
  end

  def oauth(conn, %{"code" => code}) do
    client = OAuth.exchange_code(code)

    with {:ok, me} <- OAuth.me(client) do
      case Chromoid.Accounts.get_user_by_email(me["email"]) do
        nil ->
          {:ok, user} = Chromoid.Accounts.register_user(%{"email" => me["email"]})
          Logger.info("Created user: #{inspect(user)}")

          conn
          |> put_session(:user_return_to, Routes.page_path(conn, :index))
          |> ChromoidWeb.UserAuth.log_in_user(user, me)

        user ->
          Logger.info("Logged in #{inspect(user)}")

          conn
          |> put_session(:user_return_to, Routes.page_path(conn, :index))
          |> ChromoidWeb.UserAuth.log_in_user(user, me)
      end
    end
  end
end
