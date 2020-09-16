defmodule ChromoidWeb.AdminRegistrationController do
  use ChromoidWeb, :controller

  alias Chromoid.Administration
  alias Chromoid.Administration.Admin
  alias ChromoidWeb.AdminAuth

  def new(conn, _params) do
    changeset = Administration.change_admin_registration(%Admin{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"admin" => admin_params}) do
    case Administration.register_admin(admin_params) do
      {:ok, admin} ->
        {:ok, _} =
          Administration.deliver_admin_confirmation_instructions(
            admin,
            &Routes.admin_confirmation_url(conn, :confirm, &1)
          )

        conn
        |> put_flash(:info, "Admin created successfully.")
        |> AdminAuth.log_in_admin(admin)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
