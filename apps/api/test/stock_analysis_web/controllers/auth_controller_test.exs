defmodule StockAnalysisWeb.AuthControllerTest do
  use StockAnalysisWeb.ConnCase, async: true

  alias StockAnalysis.Accounts

  @register_attrs %{
    "email" => "user@example.com",
    "password" => "password123",
    "username" => "testuser"
  }

  describe "POST /api/auth/register" do
    test "creates user and returns token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", @register_attrs)

      assert %{
               "token" => token,
               "refresh_token" => refresh_token,
               "user" => user
             } = json_response(conn, 201)

      assert is_binary(token)
      assert is_binary(refresh_token)
      assert user["email"] == "user@example.com"
      assert user["username"] == "testuser"
      assert user["id"] != nil
      refute Map.has_key?(user, "password_hash")
      refute Map.has_key?(user, "password")
    end

    test "returns 422 for duplicate email", %{conn: conn} do
      {:ok, _user} = Accounts.register_user(@register_attrs)

      conn = post(conn, ~p"/api/auth/register", %{@register_attrs | "username" => "other"})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end

    test "returns 422 for missing fields", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", %{})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end

    test "returns 422 for short password", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/register", %{@register_attrs | "password" => "short"})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/login" do
    setup do
      {:ok, user} = Accounts.register_user(@register_attrs)
      %{user: user}
    end

    test "returns token for valid credentials", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/auth/login", %{"email" => "user@example.com", "password" => "password123"})

      assert %{
               "token" => token,
               "refresh_token" => _refresh_token,
               "user" => resp_user
             } = json_response(conn, 200)

      assert is_binary(token)
      assert resp_user["id"] == user.id
      assert resp_user["email"] == "user@example.com"
    end

    test "returns 401 for wrong password", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{"email" => "user@example.com", "password" => "wrongpassword"})

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end

    test "returns 401 for non-existent email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{"email" => "nobody@example.com", "password" => "password123"})

      assert %{"error" => "invalid_credentials"} = json_response(conn, 401)
    end

    test "returns 422 for missing fields", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/login", %{})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/refresh" do
    test "returns new access token for valid refresh token", %{conn: conn} do
      {:ok, user} = Accounts.register_user(%{@register_attrs | "email" => "refresh@example.com", "username" => "refreshuser"})
      {:ok, refresh_token, _claims} = Accounts.issue_refresh_token(user)

      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => refresh_token})

      assert %{"token" => new_token} = json_response(conn, 200)
      assert is_binary(new_token)
    end

    test "returns 401 for invalid refresh token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{"refresh_token" => "invalid.token"})

      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end

    test "returns 422 for missing refresh_token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh", %{})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/forgot-password" do
    test "returns 200 for existing email", %{conn: conn} do
      {:ok, _user} = Accounts.register_user(@register_attrs)
      conn = post(conn, ~p"/api/auth/forgot-password", %{"email" => "user@example.com"})

      assert %{"message" => _} = json_response(conn, 200)
    end

    test "returns 200 for non-existent email (no leak)", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/forgot-password", %{"email" => "nobody@example.com"})

      assert %{"message" => _} = json_response(conn, 200)
    end

    test "returns 422 for missing email", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/forgot-password", %{})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end
  end

  describe "POST /api/auth/reset-password" do
    test "resets password with valid token", %{conn: conn} do
      {:ok, _user} = Accounts.register_user(%{@register_attrs | "email" => "reset@example.com", "username" => "resetuser"})
      {:ok, token, _claims} = Accounts.generate_password_reset_token("reset@example.com")

      conn = post(conn, ~p"/api/auth/reset-password", %{"token" => token, "password" => "newpassword456"})

      assert %{"message" => "Password has been reset"} = json_response(conn, 200)
    end

    test "returns 401 for invalid token", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/reset-password", %{"token" => "invalid.token", "password" => "newpassword456"})

      assert %{"error" => "invalid_token"} = json_response(conn, 401)
    end

    test "returns 422 for short password", %{conn: conn} do
      {:ok, _user} = Accounts.register_user(%{@register_attrs | "email" => "reset2@example.com", "username" => "resetuser2"})
      {:ok, token, _claims} = Accounts.generate_password_reset_token("reset2@example.com")

      conn = post(conn, ~p"/api/auth/reset-password", %{"token" => token, "password" => "short"})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end

    test "returns 422 for missing fields", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/reset-password", %{})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end
  end
end
