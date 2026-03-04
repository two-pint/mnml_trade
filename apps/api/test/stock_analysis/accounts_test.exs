defmodule StockAnalysis.AccountsTest do
  use StockAnalysis.DataCase, async: true

  alias StockAnalysis.Accounts

  @valid_attrs %{
    "email" => "test@example.com",
    "password" => "password123",
    "username" => "testuser"
  }

  describe "register_user/1" do
    test "creates a user with valid attributes" do
      assert {:ok, user} = Accounts.register_user(@valid_attrs)
      assert user.email == "test@example.com"
      assert user.username == "testuser"
      assert user.email_verified == false
      assert user.password_hash != nil
      assert user.password == nil
    end

    test "hashes the password" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert Bcrypt.verify_pass("password123", user.password_hash)
    end

    test "downcases the email" do
      {:ok, user} = Accounts.register_user(%{@valid_attrs | "email" => "Test@EXAMPLE.com"})
      assert user.email == "test@example.com"
    end

    test "rejects duplicate email" do
      {:ok, _user} = Accounts.register_user(@valid_attrs)

      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | "username" => "other"})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "rejects invalid email" do
      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | "email" => "not-an-email"})

      assert errors_on(changeset).email != []
    end

    test "rejects short password" do
      assert {:error, changeset} =
               Accounts.register_user(%{@valid_attrs | "password" => "short"})

      assert errors_on(changeset).password != []
    end

    test "registers without username" do
      attrs = Map.delete(@valid_attrs, "username")
      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.username == nil
    end
  end

  describe "authenticate_by_email_password/2" do
    test "returns user with correct credentials" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert {:ok, authenticated} = Accounts.authenticate_by_email_password("test@example.com", "password123")
      assert authenticated.id == user.id
    end

    test "returns error with wrong password" do
      {:ok, _user} = Accounts.register_user(@valid_attrs)
      assert {:error, :invalid_credentials} = Accounts.authenticate_by_email_password("test@example.com", "wrong")
    end

    test "returns error with non-existent email" do
      assert {:error, :invalid_credentials} = Accounts.authenticate_by_email_password("nobody@example.com", "password123")
    end
  end

  describe "get_user_by_email/1" do
    test "returns user by email" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert found = Accounts.get_user_by_email("test@example.com")
      assert found.id == user.id
    end

    test "is case-insensitive" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert found = Accounts.get_user_by_email("TEST@example.com")
      assert found.id == user.id
    end

    test "returns nil for unknown email" do
      assert Accounts.get_user_by_email("nobody@example.com") == nil
    end
  end

  describe "get_user_by_id/1" do
    test "returns user by id" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert found = Accounts.get_user_by_id(user.id)
      assert found.email == user.email
    end

    test "returns nil for unknown id" do
      assert Accounts.get_user_by_id(Ecto.UUID.generate()) == nil
    end
  end

  describe "issue_token/1" do
    test "returns a JWT for the user" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      assert {:ok, token, claims} = Accounts.issue_token(user)
      assert is_binary(token)
      assert claims["sub"] == user.id
    end
  end

  describe "verify_token/1" do
    test "verifies a valid token" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      {:ok, token, _claims} = Accounts.issue_token(user)

      assert {:ok, found_user, _claims} = Accounts.verify_token(token)
      assert found_user.id == user.id
    end

    test "rejects an invalid token" do
      assert {:error, _reason} = Accounts.verify_token("invalid.token.here")
    end
  end

  describe "generate_password_reset_token/1" do
    test "returns a reset token for existing user" do
      {:ok, _user} = Accounts.register_user(@valid_attrs)
      assert {:ok, token, claims} = Accounts.generate_password_reset_token("test@example.com")
      assert is_binary(token)
      assert claims["typ"] == "reset"
    end

    test "returns :noop for non-existent email" do
      assert {:ok, :noop} = Accounts.generate_password_reset_token("nobody@example.com")
    end
  end

  describe "reset_password/2" do
    test "resets password with valid reset token" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      {:ok, token, _claims} = Accounts.generate_password_reset_token("test@example.com")

      assert {:ok, updated} = Accounts.reset_password(token, "newpassword456")
      assert updated.id == user.id
      assert Bcrypt.verify_pass("newpassword456", updated.password_hash)
    end

    test "rejects non-reset token type" do
      {:ok, user} = Accounts.register_user(@valid_attrs)
      {:ok, access_token, _claims} = Accounts.issue_token(user)

      assert {:error, :invalid_token_type} = Accounts.reset_password(access_token, "newpassword456")
    end

    test "rejects invalid token" do
      assert {:error, _reason} = Accounts.reset_password("invalid.token", "newpassword456")
    end

    test "validates new password length" do
      {:ok, _user} = Accounts.register_user(@valid_attrs)
      {:ok, token, _claims} = Accounts.generate_password_reset_token("test@example.com")

      assert {:error, changeset} = Accounts.reset_password(token, "short")
      assert errors_on(changeset).password != []
    end
  end
end
