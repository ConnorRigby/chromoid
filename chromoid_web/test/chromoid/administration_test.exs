defmodule Chromoid.AdministrationTest do
  use Chromoid.DataCase

  alias Chromoid.Administration
  import Chromoid.AdministrationFixtures
  alias Chromoid.Administration.{Admin, AdminToken}

  describe "get_admin_by_email/1" do
    test "does not return the admin if the email does not exist" do
      refute Administration.get_admin_by_email("unknown@example.com")
    end

    test "returns the admin if the email exists" do
      %{id: id} = admin = admin_fixture()
      assert %Admin{id: ^id} = Administration.get_admin_by_email(admin.email)
    end
  end

  describe "get_admin_by_email_and_password/2" do
    test "does not return the admin if the email does not exist" do
      refute Administration.get_admin_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the admin if the password is not valid" do
      admin = admin_fixture()
      refute Administration.get_admin_by_email_and_password(admin.email, "invalid")
    end

    test "returns the admin if the email and password are valid" do
      %{id: id} = admin = admin_fixture()

      assert %Admin{id: ^id} =
               Administration.get_admin_by_email_and_password(admin.email, valid_admin_password())
    end
  end

  describe "get_admin!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Administration.get_admin!(-1)
      end
    end

    test "returns the admin with the given id" do
      %{id: id} = admin = admin_fixture()
      assert %Admin{id: ^id} = Administration.get_admin!(admin.id)
    end
  end

  describe "register_admin/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Administration.register_admin(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} =
        Administration.register_admin(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Administration.register_admin(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = admin_fixture()
      {:error, changeset} = Administration.register_admin(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Administration.register_admin(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers admins with a hashed password" do
      email = unique_admin_email()

      {:ok, admin} =
        Administration.register_admin(%{email: email, password: valid_admin_password()})

      assert admin.email == email
      assert is_binary(admin.hashed_password)
      assert is_nil(admin.confirmed_at)
      assert is_nil(admin.password)
    end
  end

  describe "change_admin_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Administration.change_admin_registration(%Admin{})
      assert changeset.required == [:password, :email]
    end
  end

  describe "change_admin_email/2" do
    test "returns a admin changeset" do
      assert %Ecto.Changeset{} = changeset = Administration.change_admin_email(%Admin{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_admin_email/3" do
    setup do
      %{admin: admin_fixture()}
    end

    test "requires email to change", %{admin: admin} do
      {:error, changeset} = Administration.apply_admin_email(admin, valid_admin_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{admin: admin} do
      {:error, changeset} =
        Administration.apply_admin_email(admin, valid_admin_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{admin: admin} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Administration.apply_admin_email(admin, valid_admin_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{admin: admin} do
      %{email: email} = admin_fixture()

      {:error, changeset} =
        Administration.apply_admin_email(admin, valid_admin_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{admin: admin} do
      {:error, changeset} =
        Administration.apply_admin_email(admin, "invalid", %{email: unique_admin_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{admin: admin} do
      email = unique_admin_email()

      {:ok, admin} =
        Administration.apply_admin_email(admin, valid_admin_password(), %{email: email})

      assert admin.email == email
      assert Administration.get_admin!(admin.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{admin: admin_fixture()}
    end

    test "sends token through notification", %{admin: admin} do
      token =
        extract_admin_token(fn url ->
          Administration.deliver_update_email_instructions(admin, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert admin_token = Repo.get_by(AdminToken, token: :crypto.hash(:sha256, token))
      assert admin_token.admin_id == admin.id
      assert admin_token.sent_to == admin.email
      assert admin_token.context == "change:current@example.com"
    end
  end

  describe "update_admin_email/2" do
    setup do
      admin = admin_fixture()
      email = unique_admin_email()

      token =
        extract_admin_token(fn url ->
          Administration.deliver_update_email_instructions(
            %{admin | email: email},
            admin.email,
            url
          )
        end)

      %{admin: admin, token: token, email: email}
    end

    test "updates the email with a valid token", %{admin: admin, token: token, email: email} do
      assert Administration.update_admin_email(admin, token) == :ok
      changed_admin = Repo.get!(Admin, admin.id)
      assert changed_admin.email != admin.email
      assert changed_admin.email == email
      assert changed_admin.confirmed_at
      assert changed_admin.confirmed_at != admin.confirmed_at
      refute Repo.get_by(AdminToken, admin_id: admin.id)
    end

    test "does not update email with invalid token", %{admin: admin} do
      assert Administration.update_admin_email(admin, "oops") == :error
      assert Repo.get!(Admin, admin.id).email == admin.email
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end

    test "does not update email if admin email changed", %{admin: admin, token: token} do
      assert Administration.update_admin_email(%{admin | email: "current@example.com"}, token) ==
               :error

      assert Repo.get!(Admin, admin.id).email == admin.email
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end

    test "does not update email if token expired", %{admin: admin, token: token} do
      {1, nil} = Repo.update_all(AdminToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Administration.update_admin_email(admin, token) == :error
      assert Repo.get!(Admin, admin.id).email == admin.email
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end
  end

  describe "change_admin_password/2" do
    test "returns a admin changeset" do
      assert %Ecto.Changeset{} = changeset = Administration.change_admin_password(%Admin{})
      assert changeset.required == [:password]
    end
  end

  describe "update_admin_password/3" do
    setup do
      %{admin: admin_fixture()}
    end

    test "validates password", %{admin: admin} do
      {:error, changeset} =
        Administration.update_admin_password(admin, valid_admin_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{admin: admin} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Administration.update_admin_password(admin, valid_admin_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{admin: admin} do
      {:error, changeset} =
        Administration.update_admin_password(admin, "invalid", %{password: valid_admin_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{admin: admin} do
      {:ok, admin} =
        Administration.update_admin_password(admin, valid_admin_password(), %{
          password: "new valid password"
        })

      assert is_nil(admin.password)
      assert Administration.get_admin_by_email_and_password(admin.email, "new valid password")
    end

    test "deletes all tokens for the given admin", %{admin: admin} do
      _ = Administration.generate_admin_session_token(admin)

      {:ok, _} =
        Administration.update_admin_password(admin, valid_admin_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(AdminToken, admin_id: admin.id)
    end
  end

  describe "generate_admin_session_token/1" do
    setup do
      %{admin: admin_fixture()}
    end

    test "generates a token", %{admin: admin} do
      token = Administration.generate_admin_session_token(admin)
      assert admin_token = Repo.get_by(AdminToken, token: token)
      assert admin_token.context == "session"

      # Creating the same token for another admin should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%AdminToken{
          token: admin_token.token,
          admin_id: admin_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_admin_by_session_token/1" do
    setup do
      admin = admin_fixture()
      token = Administration.generate_admin_session_token(admin)
      %{admin: admin, token: token}
    end

    test "returns admin by token", %{admin: admin, token: token} do
      assert session_admin = Administration.get_admin_by_session_token(token)
      assert session_admin.id == admin.id
    end

    test "does not return admin for invalid token" do
      refute Administration.get_admin_by_session_token("oops")
    end

    test "does not return admin for expired token", %{token: token} do
      {1, nil} = Repo.update_all(AdminToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Administration.get_admin_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      admin = admin_fixture()
      token = Administration.generate_admin_session_token(admin)
      assert Administration.delete_session_token(token) == :ok
      refute Administration.get_admin_by_session_token(token)
    end
  end

  describe "deliver_admin_confirmation_instructions/2" do
    setup do
      %{admin: admin_fixture()}
    end

    test "sends token through notification", %{admin: admin} do
      token =
        extract_admin_token(fn url ->
          Administration.deliver_admin_confirmation_instructions(admin, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert admin_token = Repo.get_by(AdminToken, token: :crypto.hash(:sha256, token))
      assert admin_token.admin_id == admin.id
      assert admin_token.sent_to == admin.email
      assert admin_token.context == "confirm"
    end
  end

  describe "confirm_admin/2" do
    setup do
      admin = admin_fixture()

      token =
        extract_admin_token(fn url ->
          Administration.deliver_admin_confirmation_instructions(admin, url)
        end)

      %{admin: admin, token: token}
    end

    test "confirms the email with a valid token", %{admin: admin, token: token} do
      assert {:ok, confirmed_admin} = Administration.confirm_admin(token)
      assert confirmed_admin.confirmed_at
      assert confirmed_admin.confirmed_at != admin.confirmed_at
      assert Repo.get!(Admin, admin.id).confirmed_at
      refute Repo.get_by(AdminToken, admin_id: admin.id)
    end

    test "does not confirm with invalid token", %{admin: admin} do
      assert Administration.confirm_admin("oops") == :error
      refute Repo.get!(Admin, admin.id).confirmed_at
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end

    test "does not confirm email if token expired", %{admin: admin, token: token} do
      {1, nil} = Repo.update_all(AdminToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Administration.confirm_admin(token) == :error
      refute Repo.get!(Admin, admin.id).confirmed_at
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end
  end

  describe "deliver_admin_reset_password_instructions/2" do
    setup do
      %{admin: admin_fixture()}
    end

    test "sends token through notification", %{admin: admin} do
      token =
        extract_admin_token(fn url ->
          Administration.deliver_admin_reset_password_instructions(admin, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert admin_token = Repo.get_by(AdminToken, token: :crypto.hash(:sha256, token))
      assert admin_token.admin_id == admin.id
      assert admin_token.sent_to == admin.email
      assert admin_token.context == "reset_password"
    end
  end

  describe "get_admin_by_reset_password_token/1" do
    setup do
      admin = admin_fixture()

      token =
        extract_admin_token(fn url ->
          Administration.deliver_admin_reset_password_instructions(admin, url)
        end)

      %{admin: admin, token: token}
    end

    test "returns the admin with valid token", %{admin: %{id: id}, token: token} do
      assert %Admin{id: ^id} = Administration.get_admin_by_reset_password_token(token)
      assert Repo.get_by(AdminToken, admin_id: id)
    end

    test "does not return the admin with invalid token", %{admin: admin} do
      refute Administration.get_admin_by_reset_password_token("oops")
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end

    test "does not return the admin if token expired", %{admin: admin, token: token} do
      {1, nil} = Repo.update_all(AdminToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Administration.get_admin_by_reset_password_token(token)
      assert Repo.get_by(AdminToken, admin_id: admin.id)
    end
  end

  describe "reset_admin_password/2" do
    setup do
      %{admin: admin_fixture()}
    end

    test "validates password", %{admin: admin} do
      {:error, changeset} =
        Administration.reset_admin_password(admin, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{admin: admin} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Administration.reset_admin_password(admin, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{admin: admin} do
      {:ok, updated_admin} =
        Administration.reset_admin_password(admin, %{password: "new valid password"})

      assert is_nil(updated_admin.password)
      assert Administration.get_admin_by_email_and_password(admin.email, "new valid password")
    end

    test "deletes all tokens for the given admin", %{admin: admin} do
      _ = Administration.generate_admin_session_token(admin)
      {:ok, _} = Administration.reset_admin_password(admin, %{password: "new valid password"})
      refute Repo.get_by(AdminToken, admin_id: admin.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%Admin{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
