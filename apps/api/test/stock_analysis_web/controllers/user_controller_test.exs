defmodule StockAnalysisWeb.UserControllerTest do
  use StockAnalysisWeb.ConnCase, async: true

  alias StockAnalysis.Accounts

  @user_attrs %{
    "email" => "me@example.com",
    "password" => "password123",
    "username" => "meuser"
  }

  setup do
    {:ok, user} = Accounts.register_user(@user_attrs)
    {:ok, token, _claims} = Accounts.issue_token(user)
    %{user: user, token: token}
  end

  describe "GET /api/user/me" do
    test "returns current user with valid token", %{conn: conn, user: user, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/user/me")

      assert %{
               "id" => id,
               "email" => "me@example.com",
               "username" => "meuser",
               "email_verified" => false
             } = json_response(conn, 200)

      assert id == user.id
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, ~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 401 with invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> get(~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end

    test "returns 401 with malformed authorization header", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "NotBearer sometoken")
        |> get(~p"/api/user/me")

      assert %{"error" => _} = json_response(conn, 401)
    end
  end
end
