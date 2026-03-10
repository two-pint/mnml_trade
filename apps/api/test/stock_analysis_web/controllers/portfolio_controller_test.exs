defmodule StockAnalysisWeb.PortfolioControllerTest do
  use StockAnalysisWeb.ConnCase, async: true

  alias StockAnalysis.Accounts

  @user_attrs %{
    "email" => "portfolio_test@example.com",
    "password" => "password123",
    "username" => "portfolio_tester"
  }

  setup do
    {:ok, user} = Accounts.register_user(@user_attrs)
    {:ok, token, _claims} = Accounts.issue_token(user)
    %{user: user, token: token}
  end

  defp auth_conn(conn, token) do
    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  describe "POST /api/paper-trading/portfolios" do
    test "creates portfolio with defaults", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios", %{"name" => "Test Portfolio"})

      assert %{
               "data" => %{
                 "id" => _id,
                 "name" => "Test Portfolio",
                 "cash_balance" => "100000",
                 "starting_balance" => "100000",
                 "is_active" => true,
                 "holdings" => []
               }
             } = json_response(conn, 201)
    end

    test "creates portfolio with custom starting balance", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios", %{
          "name" => "Custom",
          "starting_balance" => 50000
        })

      assert %{
               "data" => %{
                 "cash_balance" => "50000",
                 "starting_balance" => "50000"
               }
             } = json_response(conn, 201)
    end

    test "returns 422 without name", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios", %{})

      assert %{"error" => "validation_error"} = json_response(conn, 422)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, ~p"/api/paper-trading/portfolios", %{"name" => "Test"})
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/paper-trading/portfolios" do
    test "lists user's portfolios", %{conn: conn, user: user, token: token} do
      {:ok, _} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Portfolio 1"})

      {:ok, _} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Portfolio 2"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios")

      assert %{"data" => portfolios} = json_response(conn, 200)
      assert length(portfolios) == 2
      assert Enum.all?(portfolios, &Map.has_key?(&1, "holdings_count"))
    end

    test "does not list another user's portfolios", %{conn: conn, token: token} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_list@example.com",
          "password" => "password123",
          "username" => "other_list"
        })

      {:ok, _} =
        StockAnalysis.PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/paper-trading/portfolios/:id" do
    test "shows portfolio with holdings", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Show Me"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}")

      assert %{
               "data" => %{
                 "id" => _,
                 "name" => "Show Me",
                 "holdings" => []
               }
             } = json_response(conn, 200)
    end

    test "returns 404 for another user's portfolio", %{conn: conn, token: token} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_show@example.com",
          "password" => "password123",
          "username" => "other_show"
        })

      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(other.id, %{"name" => "Private"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}")

      assert json_response(conn, 404)
    end

    test "returns 404 for non-existent id", %{conn: conn, token: token} do
      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/paper-trading/portfolios/:id" do
    test "updates name and description", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Original"})

      conn =
        conn
        |> auth_conn(token)
        |> put(~p"/api/paper-trading/portfolios/#{portfolio.id}", %{
          "name" => "Renamed",
          "description" => "A description"
        })

      assert %{
               "data" => %{
                 "name" => "Renamed",
                 "description" => "A description"
               }
             } = json_response(conn, 200)
    end

    test "does not allow changing balances", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Test"})

      conn =
        conn
        |> auth_conn(token)
        |> put(~p"/api/paper-trading/portfolios/#{portfolio.id}", %{
          "name" => "Test",
          "cash_balance" => "999999"
        })

      assert %{"data" => %{"cash_balance" => "100000"}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/paper-trading/portfolios/:id" do
    test "deletes the portfolio", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Delete Me"})

      conn =
        conn
        |> auth_conn(token)
        |> delete(~p"/api/paper-trading/portfolios/#{portfolio.id}")

      assert response(conn, 204)

      conn =
        build_conn()
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}")

      assert json_response(conn, 404)
    end

    test "returns 404 for another user's portfolio", %{conn: conn, token: token} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_del@example.com",
          "password" => "password123",
          "username" => "other_del"
        })

      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(other.id, %{"name" => "Private"})

      conn =
        conn
        |> auth_conn(token)
        |> delete(~p"/api/paper-trading/portfolios/#{portfolio.id}")

      assert json_response(conn, 404)
    end
  end
end
