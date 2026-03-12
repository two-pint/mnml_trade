defmodule StockAnalysisWeb.EngagementControllerTest do
  use StockAnalysisWeb.ConnCase, async: true

  alias StockAnalysis.Accounts

  @user_attrs %{
    "email" => "engage_ctrl_test@example.com",
    "password" => "password123",
    "username" => "engage_ctrl_tester"
  }

  setup do
    {:ok, user} = Accounts.register_user(@user_attrs)
    {:ok, token, _claims} = Accounts.issue_token(user)
    %{user: user, token: token}
  end

  defp auth_conn(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  # --- Watchlist ---

  describe "GET /api/user/watchlist" do
    test "returns empty list when no items", %{conn: conn, token: token} do
      conn = conn |> auth_conn(token) |> get(~p"/api/user/watchlist")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, ~p"/api/user/watchlist")
      assert conn.status == 401
    end
  end

  describe "POST /api/user/watchlist" do
    test "adds ticker to watchlist", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/user/watchlist", %{"ticker" => "AAPL"})

      assert %{"data" => %{"ticker" => "AAPL", "id" => _id, "added_at" => _}} =
               json_response(conn, 201)
    end

    test "duplicate add returns existing item", %{conn: conn, token: token} do
      conn
      |> auth_conn(token)
      |> post(~p"/api/user/watchlist", %{"ticker" => "AAPL"})

      conn2 =
        build_conn()
        |> auth_conn(token)
        |> post(~p"/api/user/watchlist", %{"ticker" => "AAPL"})

      assert %{"data" => %{"ticker" => "AAPL"}} = json_response(conn2, 201)
    end

    test "rejects empty ticker", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/user/watchlist", %{"ticker" => ""})

      assert conn.status == 422
    end

    test "list reflects added items", %{conn: conn, token: token} do
      conn |> auth_conn(token) |> post(~p"/api/user/watchlist", %{"ticker" => "AAPL"})
      build_conn() |> auth_conn(token) |> post(~p"/api/user/watchlist", %{"ticker" => "MSFT"})

      list_conn = build_conn() |> auth_conn(token) |> get(~p"/api/user/watchlist")
      assert %{"data" => items} = json_response(list_conn, 200)
      tickers = Enum.map(items, & &1["ticker"])
      assert "AAPL" in tickers
      assert "MSFT" in tickers
    end
  end

  describe "DELETE /api/user/watchlist/:ticker" do
    test "removes ticker from watchlist", %{conn: conn, token: token} do
      conn |> auth_conn(token) |> post(~p"/api/user/watchlist", %{"ticker" => "AAPL"})

      del_conn =
        build_conn()
        |> auth_conn(token)
        |> delete(~p"/api/user/watchlist/AAPL")

      assert del_conn.status == 204

      list_conn = build_conn() |> auth_conn(token) |> get(~p"/api/user/watchlist")
      assert %{"data" => []} = json_response(list_conn, 200)
    end

    test "returns 404 for non-existent ticker", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> delete(~p"/api/user/watchlist/NOPE")

      assert conn.status == 404
    end
  end

  # --- History ---

  describe "GET /api/user/history" do
    test "returns empty list initially", %{conn: conn, token: token} do
      conn = conn |> auth_conn(token) |> get(~p"/api/user/history")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns history after manual record", %{conn: conn, token: token, user: user} do
      StockAnalysis.Engagement.record_view(user.id, "AAPL")
      StockAnalysis.Engagement.record_view(user.id, "MSFT")

      conn = conn |> auth_conn(token) |> get(~p"/api/user/history")
      assert %{"data" => entries} = json_response(conn, 200)
      tickers = Enum.map(entries, & &1["ticker"])
      assert "AAPL" in tickers
      assert "MSFT" in tickers
    end

    test "returns 401 without token", %{conn: conn} do
      conn = get(conn, ~p"/api/user/history")
      assert conn.status == 401
    end
  end
end
