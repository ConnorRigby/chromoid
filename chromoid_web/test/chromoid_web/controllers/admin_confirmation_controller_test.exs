defmodule ChromoidWeb.AdminConfirmationControllerTest do
  use ChromoidWeb.ConnCase, async: true

  alias Chromoid.Administration
  alias Chromoid.Repo
  import Chromoid.AdministrationFixtures

  setup do
    %{admin: admin_fixture()}
  end

  describe "GET /admins/confirm" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.admin_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /admins/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, admin: admin} do
      conn =
        post(conn, Routes.admin_confirmation_path(conn, :create), %{
          "admin" => %{"email" => admin.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(Administration.AdminToken, admin_id: admin.id).context == "confirm"
    end

    test "does not send confirmation token if account is confirmed", %{conn: conn, admin: admin} do
      Repo.update!(Administration.Admin.confirm_changeset(admin))

      conn =
        post(conn, Routes.admin_confirmation_path(conn, :create), %{
          "admin" => %{"email" => admin.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(Administration.AdminToken, admin_id: admin.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.admin_confirmation_path(conn, :create), %{
          "admin" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(Administration.AdminToken) == []
    end
  end

  describe "GET /admins/confirm/:token" do
    test "confirms the given token once", %{conn: conn, admin: admin} do
      token =
        extract_admin_token(fn url ->
          Administration.deliver_admin_confirmation_instructions(admin, url)
        end)

      conn = get(conn, Routes.admin_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Account confirmed successfully"
      assert Administration.get_admin!(admin.id).confirmed_at
      refute get_session(conn, :admin_token)
      assert Repo.all(Administration.AdminToken) == []

      conn = get(conn, Routes.admin_confirmation_path(conn, :confirm, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
    end

    test "does not confirm email with invalid token", %{conn: conn, admin: admin} do
      conn = get(conn, Routes.admin_confirmation_path(conn, :confirm, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Confirmation link is invalid or it has expired"
      refute Administration.get_admin!(admin.id).confirmed_at
    end
  end
end
