defmodule ChromoidDiscord.OauthNew do
  @client_id Application.get_env(:nostrum, :client_id)
  @client_secret Application.get_env(:nostrum, :client_secret)
  # @url "http://localhost:4000/discord/oauth"

  def client do
    OAuth2.Client.new(
      # default
      strategy: OAuth2.Strategy.AuthCode,
      client_id: @client_id,
      client_secret: @client_secret,
      site: "https://discord.com/api/v8",
      redirect_uri: "http://localhost:4000/discord/oauth",
      params: %{
        scope: "email",
        prompt: "consent"
      }
    )
  end

  def exchange_code(code) do
    client = OAuth2.Client.get_token!(client(), code: code)
  end

  def url(client) do
    OAuth2.Client.authorize_url!(client)
  end
end
