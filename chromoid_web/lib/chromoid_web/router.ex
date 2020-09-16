defmodule ChromoidWeb.Router do
  use ChromoidWeb, :router
  import Phoenix.LiveDashboard.Router

  import ChromoidWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_admin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChromoidWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  ## Authentication routes

  scope "/", ChromoidWeb do
    pipe_through [:browser, :redirect_if_admin_is_authenticated]

    get "/admins/register", AdminRegistrationController, :new
    post "/admins/register", AdminRegistrationController, :create
    get "/admins/log_in", AdminSessionController, :new
    post "/admins/log_in", AdminSessionController, :create
    get "/admins/reset_password", AdminResetPasswordController, :new
    post "/admins/reset_password", AdminResetPasswordController, :create
    get "/admins/reset_password/:token", AdminResetPasswordController, :edit
    put "/admins/reset_password/:token", AdminResetPasswordController, :update
  end

  scope "/", ChromoidWeb do
    pipe_through [:browser, :require_authenticated_admin]

    get "/admins/settings", AdminSettingsController, :edit
    put "/admins/settings/update_password", AdminSettingsController, :update_password
    put "/admins/settings/update_email", AdminSettingsController, :update_email
    get "/admins/settings/confirm_email/:token", AdminSettingsController, :confirm_email

    resources "/devices", DeviceController, only: [:index, :show]
    live_dashboard "/dashboard", metrics: ChromoidWeb.Telemetry
  end

  scope "/", ChromoidWeb do
    pipe_through [:browser]

    delete "/admins/log_out", AdminSessionController, :delete
    get "/admins/confirm", AdminConfirmationController, :new
    post "/admins/confirm", AdminConfirmationController, :create
    get "/admins/confirm/:token", AdminConfirmationController, :confirm
  end
end
