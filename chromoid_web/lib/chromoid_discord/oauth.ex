defmodule ChromoidDiscord.OAuth do
  @client_id Application.get_env(:nostrum, :client_id)
  @client_secret Application.get_env(:nostrum, :client_secret)

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

  def authorization_url(state \\ "") do
    query =
      URI.encode_query(%{
        "client_id" => @client_id,
        "prompt" => "consent",
        "redirect_uri" => discord_oauth_url(@endpoint, :oauth),
        "response_type" => "code",
        "scope" => "email guilds.join",
        "state" => state
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
    else
      %Tesla.Env{} = env ->
        env = Tesla.Middleware.JSON.decode(env, [])
        raise inspect(env.body)
    end
  end

  def me(client) do
    case get(client, "/users/@me") do
      {:ok, %Tesla.Env{body: body}} -> {:ok, body}
      error -> error
    end
  end
end
