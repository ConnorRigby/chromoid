defmodule ChromoidDiscord.OAuth do
  @client_id 755_805_360_123_805_987
  @client_secret "TN85dQdi-wQ1sAIsD_qPPegqrZlgWMoB"
  # @token "NzU1ODA1MzYwMTIzODA1OTg3.X2IomA.3ZHpLMS4frz4CfvuiNojMBQ157E"

  use Tesla
  plug Tesla.Middleware.Logger
  plug Tesla.Middleware.BaseUrl, "https://discord.com/api/v6"

  plug Tesla.Middleware.Headers, [
    # {"Authorization", "Bot " <> @token}
  ]

  plug Tesla.Middleware.FormUrlencoded
  plug Tesla.Middleware.FollowRedirects

  import ChromoidWeb.Router.Helpers
  @endpoint ChromoidWeb.Endpoint

  def authorization_url do
    query =
      URI.encode_query(%{
        "client_id" => @client_id,
        "prompt" => "consent",
        "redirect_uri" => discord_oauth_url(@endpoint, :oauth),
        "response_type" => "code",
        "scope" => "email guilds.join",
        "state" => "15773059ghq9183habn"
      })

    %URI{
      authority: "discord.com",
      fragment: nil,
      host: "discord.com",
      path: "/api/oauth2/authorize",
      port: 443,
      query: query,
      scheme: "https",
      userinfo: nil
    }
    |> to_string()
  end

  def client(%{"access_token" => token, "token_type" => type}) do
    middleware = [
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"Authorization", "#{type} " <> token}]}
    ]

    Tesla.client(middleware)
  end

  def exchange_code(code) do
    response =
      post!("/oauth2/token", %{
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: "authorization_code",
        code: code,
        redirect_uri: discord_oauth_url(@endpoint, :oauth),
        scope: "identify email connections"
      })

    with %Tesla.Env{status: 200} = env <- response,
         {:ok, %Tesla.Env{body: body}} <- Tesla.Middleware.JSON.decode(env, []) do
      client(body)
    end
  end

  def me(client) do
    case get(client, "/users/@me") do
      {:ok, %Tesla.Env{body: body}} -> {:ok, body}
      error -> error
    end
  end
end
