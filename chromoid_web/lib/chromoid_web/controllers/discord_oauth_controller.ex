defmodule ChromoidWeb.DiscordOauthController do
  use ChromoidWeb, :controller
  alias ChromoidDiscord.OAuth
  require Logger

  def logout(conn, _) do
    ChromoidWeb.UserAuth.log_out_user(conn)
  end

  def oauth(conn, %{"code" => code} = params) do
    Logger.info("Discord Oauth: #{inspect(params)}")
    # send_resp(conn, 200, code)
    client = OAuth.exchange_code(code)
    IO.inspect(client, label: "CLIENT!!!")

    with {:ok, me} <- OAuth.me(client),
         _ <- Logger.warn("oauth result: #{inspect(me)}") do
      case Chromoid.Accounts.get_user_by_email(me["email"]) do
        nil ->
          {:ok, user} = Chromoid.Accounts.register_user(%{"email" => me["email"]})
          {:ok, user} = Chromoid.Accounts.sync_discord(user, me)
          Logger.info("Created user: #{inspect(user)}")

          conn
          |> put_session(:user_return_to, Routes.page_path(conn, :index))
          |> ChromoidWeb.UserAuth.log_in_user(user, me)

        user ->
          {:ok, user} = Chromoid.Accounts.sync_discord(user, me)
          Logger.info("Logged in #{inspect(user)}")

          conn
          |> put_session(:user_return_to, Routes.page_path(conn, :index))
          |> ChromoidWeb.UserAuth.log_in_user(user, me)
      end
    end
  end

  def oauth(conn, %{"error" => error, "error_description" => reason}) do
    conn
    |> put_flash(:error, "#{error} #{reason}")
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
