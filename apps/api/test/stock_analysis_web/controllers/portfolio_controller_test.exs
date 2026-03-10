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

  describe "POST /api/paper-trading/portfolios/:portfolio_id/trade" do
    defp seed_price_in_cache(ticker, price) do
      cache_key = StockAnalysis.Cache.key("stocks", String.upcase(ticker), "price")
      StockAnalysis.Cache.put(cache_key, %{price: price}, 60)
    end

    test "executes a buy trade", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Trade Test"})

      seed_price_in_cache("AAPL", "175")

      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "buy",
          "quantity" => 10
        })

      assert %{
               "data" => %{
                 "transaction" => %{
                   "ticker" => "AAPL",
                   "side" => "buy",
                   "quantity" => "10",
                   "price_per_share" => "175",
                   "total_amount" => "1750"
                 },
                 "portfolio" => %{
                   "cash_balance" => "98250",
                   "holdings" => [%{"ticker" => "AAPL", "quantity" => "10"}]
                 }
               }
             } = json_response(conn, 201)
    end

    test "executes a sell trade", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Sell Test"})

      seed_price_in_cache("AAPL", "175")

      build_conn()
      |> auth_conn(token)
      |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
        "ticker" => "AAPL",
        "side" => "buy",
        "quantity" => 10
      })

      seed_price_in_cache("AAPL", "180")

      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "sell",
          "quantity" => 5
        })

      assert %{
               "data" => %{
                 "transaction" => %{"side" => "sell", "quantity" => "5"},
                 "portfolio" => %{
                   "holdings" => [%{"quantity" => "5"}]
                 }
               }
             } = json_response(conn, 201)
    end

    test "returns 422 for insufficient funds", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{
          "name" => "Broke",
          "starting_balance" => "100"
        })

      seed_price_in_cache("AAPL", "175")

      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "buy",
          "quantity" => 10
        })

      assert %{"error" => "insufficient_funds"} = json_response(conn, 422)
    end

    test "returns 422 for invalid side", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Bad Side"})

      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "hold",
          "quantity" => 1
        })

      assert %{"error" => "invalid_side"} = json_response(conn, 422)
    end

    test "returns 422 for invalid quantity", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Bad Qty"})

      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "buy",
          "quantity" => 0
        })

      assert %{"error" => "invalid_quantity"} = json_response(conn, 422)
    end

    test "returns 404 for another user's portfolio", %{conn: conn, token: token} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_trade@example.com",
          "password" => "password123",
          "username" => "other_trade"
        })

      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(other.id, %{"name" => "Private"})

      seed_price_in_cache("AAPL", "100")

      conn =
        conn
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "buy",
          "quantity" => 1
        })

      assert json_response(conn, 404)
    end

    test "returns 401 without auth", %{conn: conn, user: user} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "No Auth"})

      conn =
        post(conn, ~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL",
          "side" => "buy",
          "quantity" => 1
        })

      assert json_response(conn, 401)
    end
  end

  describe "GET /api/paper-trading/portfolios/:portfolio_id/holdings" do
    test "returns enriched holdings", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "Holdings"})

      seed_price_in_cache("AAPL", "175")

      build_conn()
      |> auth_conn(token)
      |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
        "ticker" => "AAPL", "side" => "buy", "quantity" => 10
      })

      seed_price_in_cache("AAPL", "180")

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/holdings")

      assert %{"data" => [holding]} = json_response(conn, 200)
      assert holding["ticker"] == "AAPL"
      assert holding["current_price"] == "180"
      assert holding["current_value"] != nil
      assert holding["gain_loss"] != nil
      assert holding["gain_loss_percent"] != nil
    end

    test "returns 404 for another user's portfolio", %{conn: conn, token: token} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_hold@example.com",
          "password" => "password123",
          "username" => "other_hold"
        })

      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(other.id, %{"name" => "Private"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/holdings")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/paper-trading/portfolios/:portfolio_id/transactions" do
    test "returns paginated transactions", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "TxList"})

      seed_price_in_cache("AAPL", "100")

      for _ <- 1..3 do
        build_conn()
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL", "side" => "buy", "quantity" => 1
        })
      end

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/transactions?per_page=2&page=1")

      response = json_response(conn, 200)
      assert length(response["data"]) == 2
      assert response["meta"]["total_count"] == 3
      assert response["meta"]["total_pages"] == 2
    end

    test "filters by ticker", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "TxFilter"})

      seed_price_in_cache("AAPL", "100")
      seed_price_in_cache("MSFT", "200")

      build_conn()
      |> auth_conn(token)
      |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
        "ticker" => "AAPL", "side" => "buy", "quantity" => 1
      })

      build_conn()
      |> auth_conn(token)
      |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
        "ticker" => "MSFT", "side" => "buy", "quantity" => 1
      })

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/transactions?ticker=AAPL")

      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert hd(response["data"])["ticker"] == "AAPL"
    end
  end

  describe "GET /api/paper-trading/portfolios/:portfolio_id/transactions/:transaction_id" do
    test "returns single transaction detail", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "TxDetail"})

      seed_price_in_cache("AAPL", "150")

      trade_conn =
        build_conn()
        |> auth_conn(token)
        |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
          "ticker" => "AAPL", "side" => "buy", "quantity" => 5
        })

      %{"data" => %{"transaction" => %{"id" => tx_id}}} = json_response(trade_conn, 201)

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/transactions/#{tx_id}")

      assert %{"data" => %{"id" => ^tx_id, "ticker" => "AAPL"}} = json_response(conn, 200)
    end

    test "returns 404 for non-existent transaction", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "NoTx"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/transactions/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end
  end

  describe "GET /api/paper-trading/portfolios/:portfolio_id/performance" do
    test "returns zero metrics for empty portfolio", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "EmptyPerf"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/performance")

      response = json_response(conn, 200)
      assert response["data"]["total_value"] == "100000"
      assert response["data"]["total_return"] == "0"
      assert response["data"]["win_rate"] == "0"
      assert response["data"]["total_trades"] == 0
      assert response["data"]["best_trade"] == nil
      assert response["data"]["worst_trade"] == nil
    end

    test "returns metrics after trades", %{conn: conn, user: user, token: token} do
      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(user.id, %{"name" => "PerfTest"})

      seed_price_in_cache("AAPL", "170")

      build_conn()
      |> auth_conn(token)
      |> post(~p"/api/paper-trading/portfolios/#{portfolio.id}/trade", %{
        "ticker" => "AAPL", "side" => "buy", "quantity" => 10
      })

      seed_price_in_cache("AAPL", "180")

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/performance")

      response = json_response(conn, 200)
      assert response["data"]["total_trades"] == 1
      assert response["data"]["most_traded_ticker"] == "AAPL"
    end

    test "returns 404 for another user's portfolio", %{conn: conn, token: token} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_perf@example.com",
          "password" => "password123",
          "username" => "other_perf"
        })

      {:ok, portfolio} =
        StockAnalysis.PaperTrading.create_portfolio(other.id, %{"name" => "Private"})

      conn =
        conn
        |> auth_conn(token)
        |> get(~p"/api/paper-trading/portfolios/#{portfolio.id}/performance")

      assert json_response(conn, 404)
    end
  end
end
