defmodule ChromoidWeb.Router do
  use ChromoidWeb, :router

  import ChromoidWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  scope "/", ChromoidWeb do
    pipe_through :browser
    get "/", PageController, :index
    get "/discord/oauth", DiscordOauthController, :oauth
  end

  ## Authentication routes

  scope "/", ChromoidWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", ChromoidWeb do
    pipe_through [:browser, :require_authenticated_user]
    get "/logout", DiscordOauthController, :logout
    live_dashboard "/dashboard", metrics: ChromoidWeb.Telemetry
    resources "/devices", DeviceController, only: [:index, :show]
  end

  scope "/", ChromoidWeb do
    pipe_through [:browser]

    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :confirm
  end
end
