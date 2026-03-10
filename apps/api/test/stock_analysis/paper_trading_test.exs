defmodule StockAnalysis.PaperTradingTest do
  use StockAnalysis.DataCase, async: true

  alias StockAnalysis.{Accounts, PaperTrading}
  alias StockAnalysis.PaperTrading.Portfolio

  @user_attrs %{
    "email" => "trader@example.com",
    "password" => "password123",
    "username" => "trader"
  }

  setup do
    {:ok, user} = Accounts.register_user(@user_attrs)
    %{user: user}
  end

  describe "create_portfolio/2" do
    test "creates a portfolio with defaults", %{user: user} do
      assert {:ok, %Portfolio{} = portfolio} =
               PaperTrading.create_portfolio(user.id, %{"name" => "My Portfolio"})

      assert portfolio.name == "My Portfolio"
      assert portfolio.user_id == user.id
      assert portfolio.is_active == true
      assert Decimal.equal?(portfolio.starting_balance, Decimal.new("100000"))
      assert Decimal.equal?(portfolio.cash_balance, Decimal.new("100000"))
      assert portfolio.description == nil
    end

    test "creates a portfolio with custom starting balance", %{user: user} do
      assert {:ok, portfolio} =
               PaperTrading.create_portfolio(user.id, %{
                 "name" => "Custom",
                 "starting_balance" => "50000"
               })

      assert Decimal.equal?(portfolio.starting_balance, Decimal.new("50000"))
      assert Decimal.equal?(portfolio.cash_balance, Decimal.new("50000"))
    end

    test "fails without name", %{user: user} do
      assert {:error, changeset} = PaperTrading.create_portfolio(user.id, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_portfolios/1" do
    test "returns only active portfolios for the user", %{user: user} do
      {:ok, _p1} = PaperTrading.create_portfolio(user.id, %{"name" => "Active"})
      {:ok, p2} = PaperTrading.create_portfolio(user.id, %{"name" => "Inactive"})

      p2
      |> Ecto.Changeset.change(is_active: false)
      |> Repo.update!()

      portfolios = PaperTrading.list_portfolios(user.id)
      assert length(portfolios) == 1
      assert hd(portfolios).name == "Active"
    end

    test "does not return portfolios from other users", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other@example.com",
          "password" => "password123",
          "username" => "other"
        })

      {:ok, _} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})
      {:ok, _} = PaperTrading.create_portfolio(user.id, %{"name" => "Mine"})

      portfolios = PaperTrading.list_portfolios(user.id)
      assert length(portfolios) == 1
      assert hd(portfolios).name == "Mine"
    end
  end

  describe "get_portfolio/2" do
    test "returns portfolio with holdings preloaded", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Test"})

      assert {:ok, fetched} = PaperTrading.get_portfolio(user.id, portfolio.id)
      assert fetched.id == portfolio.id
      assert fetched.holdings == []
    end

    test "returns not_found for non-existent id", %{user: user} do
      assert {:error, :not_found} =
               PaperTrading.get_portfolio(user.id, Ecto.UUID.generate())
    end

    test "returns not_found for another user's portfolio", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other2@example.com",
          "password" => "password123",
          "username" => "other2"
        })

      {:ok, portfolio} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      assert {:error, :not_found} = PaperTrading.get_portfolio(user.id, portfolio.id)
    end
  end

  describe "update_portfolio/3" do
    test "updates name and description", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Original"})

      assert {:ok, updated} =
               PaperTrading.update_portfolio(user.id, portfolio.id, %{
                 "name" => "Renamed",
                 "description" => "A description"
               })

      assert updated.name == "Renamed"
      assert updated.description == "A description"
    end

    test "does not allow changing cash_balance", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Test"})
      original_balance = portfolio.cash_balance

      {:ok, updated} =
        PaperTrading.update_portfolio(user.id, portfolio.id, %{
          "name" => "Test",
          "cash_balance" => "999999"
        })

      assert Decimal.equal?(updated.cash_balance, original_balance)
    end

    test "returns not_found for another user's portfolio", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other3@example.com",
          "password" => "password123",
          "username" => "other3"
        })

      {:ok, portfolio} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      assert {:error, :not_found} =
               PaperTrading.update_portfolio(user.id, portfolio.id, %{"name" => "Hacked"})
    end
  end

  describe "delete_portfolio/2" do
    test "deletes the portfolio", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Delete Me"})

      assert {:ok, _} = PaperTrading.delete_portfolio(user.id, portfolio.id)
      assert {:error, :not_found} = PaperTrading.get_portfolio(user.id, portfolio.id)
    end

    test "returns not_found for another user's portfolio", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other4@example.com",
          "password" => "password123",
          "username" => "other4"
        })

      {:ok, portfolio} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      assert {:error, :not_found} = PaperTrading.delete_portfolio(user.id, portfolio.id)
    end
  end

  describe "execute_trade/4" do
    defp price_fetcher(price_string) do
      fn _ticker -> {:ok, %{price: price_string}} end
    end

    test "buy creates holding and deducts cash", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Trade Test"})

      assert {:ok, %{transaction: tx, portfolio: updated}} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
                 price_fetcher: price_fetcher("175")
               )

      assert tx.ticker == "AAPL"
      assert tx.transaction_type == "buy"
      assert Decimal.equal?(tx.quantity, Decimal.new("10"))
      assert Decimal.equal?(tx.price_per_share, Decimal.new("175"))
      assert Decimal.equal?(tx.total_amount, Decimal.new("1750"))

      assert Decimal.equal?(updated.cash_balance, Decimal.new("98250"))
      assert length(updated.holdings) == 1

      holding = hd(updated.holdings)
      assert holding.ticker == "AAPL"
      assert Decimal.equal?(holding.quantity, Decimal.new("10"))
      assert Decimal.equal?(holding.average_cost, Decimal.new("175"))
    end

    test "second buy recalculates average cost", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Avg Cost"})

      {:ok, _} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("175")
        )

      {:ok, %{portfolio: updated}} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("180")
        )

      # Cash: 100_000 - 1_750 - 1_800 = 96_450
      assert Decimal.equal?(updated.cash_balance, Decimal.new("96450"))

      holding = hd(updated.holdings)
      assert Decimal.equal?(holding.quantity, Decimal.new("20"))
      # avg = (1750 + 1800) / 20 = 177.50
      assert Decimal.equal?(holding.average_cost, Decimal.new("177.5"))
    end

    test "sell adds cash and reduces holding", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Sell Test"})

      {:ok, _} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 20},
          price_fetcher: price_fetcher("177.50")
        )

      {:ok, %{transaction: tx, portfolio: updated}} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "sell", "quantity" => 5},
          price_fetcher: price_fetcher("180")
        )

      assert tx.transaction_type == "sell"
      assert Decimal.equal?(tx.total_amount, Decimal.new("900"))

      # Cash: 100_000 - 3_550 + 900 = 97_350
      assert Decimal.equal?(updated.cash_balance, Decimal.new("97350"))

      holding = hd(updated.holdings)
      assert Decimal.equal?(holding.quantity, Decimal.new("15"))
      # avg cost unchanged from buy
      assert Decimal.equal?(holding.average_cost, Decimal.new("177.5"))
    end

    test "selling all shares removes the holding", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Sell All"})

      {:ok, _} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("100")
        )

      {:ok, %{portfolio: updated}} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "sell", "quantity" => 10},
          price_fetcher: price_fetcher("110")
        )

      assert updated.holdings == []
      # Cash: 100_000 - 1_000 + 1_100 = 100_100
      assert Decimal.equal?(updated.cash_balance, Decimal.new("100100"))
    end

    test "buy with insufficient cash returns error", %{user: user} do
      {:ok, portfolio} =
        PaperTrading.create_portfolio(user.id, %{"name" => "Broke", "starting_balance" => "500"})

      assert {:error, :insufficient_funds} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
                 price_fetcher: price_fetcher("100")
               )

      # Verify no side effects
      {:ok, unchanged} = PaperTrading.get_portfolio(user.id, portfolio.id)
      assert Decimal.equal?(unchanged.cash_balance, Decimal.new("500"))
      assert unchanged.holdings == []
    end

    test "sell more than owned returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Oversell"})

      {:ok, _} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("100")
        )

      assert {:error, :insufficient_shares} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "sell", "quantity" => 100},
                 price_fetcher: price_fetcher("100")
               )
    end

    test "sell with no holding returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "No Holding"})

      assert {:error, :insufficient_shares} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "sell", "quantity" => 1},
                 price_fetcher: price_fetcher("100")
               )
    end

    test "quantity of 0 returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Zero Qty"})

      assert {:error, :invalid_quantity} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "buy", "quantity" => 0},
                 price_fetcher: price_fetcher("100")
               )
    end

    test "negative quantity returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Neg Qty"})

      assert {:error, :invalid_quantity} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "buy", "quantity" => -1},
                 price_fetcher: price_fetcher("100")
               )
    end

    test "quantity exceeding 10_000 returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Max Qty"})

      assert {:error, :invalid_quantity} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10_001},
                 price_fetcher: price_fetcher("1")
               )
    end

    test "invalid side returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Bad Side"})

      assert {:error, :invalid_side} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "hold", "quantity" => 1},
                 price_fetcher: price_fetcher("100")
               )
    end

    test "missing ticker returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "No Ticker"})

      assert {:error, :invalid_ticker} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"side" => "buy", "quantity" => 1},
                 price_fetcher: price_fetcher("100")
               )
    end

    test "price fetch failure returns error", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "No Price"})

      assert {:error, :price_unavailable} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "FAKE", "side" => "buy", "quantity" => 1},
                 price_fetcher: fn _ticker -> {:error, :not_found} end
               )
    end

    test "ticker is case-insensitive", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Case Test"})

      {:ok, %{portfolio: updated}} =
        PaperTrading.execute_trade(
          user.id,
          portfolio.id,
          %{"ticker" => "aapl", "side" => "buy", "quantity" => 5},
          price_fetcher: price_fetcher("100")
        )

      holding = hd(updated.holdings)
      assert holding.ticker == "AAPL"
    end

    test "cannot trade on another user's portfolio", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_trade@example.com",
          "password" => "password123",
          "username" => "other_trade"
        })

      {:ok, portfolio} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      assert {:error, :not_found} =
               PaperTrading.execute_trade(
                 user.id,
                 portfolio.id,
                 %{"ticker" => "AAPL", "side" => "buy", "quantity" => 1},
                 price_fetcher: price_fetcher("100")
               )
    end
  end

  describe "list_holdings/3" do
    defp price_fetcher_for_holdings(prices) do
      fn ticker ->
        case Map.get(prices, ticker) do
          nil -> {:error, :not_found}
          p -> {:ok, %{price: p}}
        end
      end
    end

    test "returns enriched holdings with gain/loss", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Holdings Test"})

      {:ok, _} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("100")
        )

      {:ok, _} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "MSFT", "side" => "buy", "quantity" => 5},
          price_fetcher: price_fetcher("200")
        )

      {:ok, holdings} =
        PaperTrading.list_holdings(user.id, portfolio.id,
          price_fetcher: price_fetcher_for_holdings(%{"AAPL" => "120", "MSFT" => "190"})
        )

      assert length(holdings) == 2
      aapl = Enum.find(holdings, fn h -> h.holding.ticker == "AAPL" end)
      assert Decimal.equal?(aapl.current_price, Decimal.new("120"))
      assert Decimal.equal?(aapl.current_value, Decimal.new("1200"))
      assert Decimal.equal?(aapl.gain_loss, Decimal.new("200"))

      msft = Enum.find(holdings, fn h -> h.holding.ticker == "MSFT" end)
      assert Decimal.equal?(msft.current_price, Decimal.new("190"))
      assert Decimal.equal?(msft.current_value, Decimal.new("950"))
      assert Decimal.lt?(msft.gain_loss, Decimal.new("0"))
    end

    test "returns not_found for another user", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_hold@example.com",
          "password" => "password123",
          "username" => "other_hold"
        })

      {:ok, portfolio} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      assert {:error, :not_found} = PaperTrading.list_holdings(user.id, portfolio.id)
    end
  end

  describe "list_transactions/3" do
    test "returns paginated transactions", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Tx Test"})

      for i <- 1..5 do
        {:ok, _} =
          PaperTrading.execute_trade(user.id, portfolio.id,
            %{"ticker" => "AAPL", "side" => "buy", "quantity" => i},
            price_fetcher: price_fetcher("100")
          )
      end

      {:ok, result} = PaperTrading.list_transactions(user.id, portfolio.id, %{"per_page" => "2", "page" => "1"})
      assert length(result.transactions) == 2
      assert result.total_count == 5
      assert result.total_pages == 3
      assert result.page == 1

      {:ok, page2} = PaperTrading.list_transactions(user.id, portfolio.id, %{"per_page" => "2", "page" => "2"})
      assert length(page2.transactions) == 2
    end

    test "filters by ticker", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Filter Test"})

      {:ok, _} = PaperTrading.execute_trade(user.id, portfolio.id,
        %{"ticker" => "AAPL", "side" => "buy", "quantity" => 1},
        price_fetcher: price_fetcher("100"))

      {:ok, _} = PaperTrading.execute_trade(user.id, portfolio.id,
        %{"ticker" => "MSFT", "side" => "buy", "quantity" => 1},
        price_fetcher: price_fetcher("200"))

      {:ok, result} = PaperTrading.list_transactions(user.id, portfolio.id, %{"ticker" => "AAPL"})
      assert length(result.transactions) == 1
      assert hd(result.transactions).ticker == "AAPL"
    end

    test "filters by type", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Type Filter"})

      {:ok, _} = PaperTrading.execute_trade(user.id, portfolio.id,
        %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
        price_fetcher: price_fetcher("100"))

      {:ok, _} = PaperTrading.execute_trade(user.id, portfolio.id,
        %{"ticker" => "AAPL", "side" => "sell", "quantity" => 5},
        price_fetcher: price_fetcher("110"))

      {:ok, buys} = PaperTrading.list_transactions(user.id, portfolio.id, %{"type" => "buy"})
      assert length(buys.transactions) == 1
      assert hd(buys.transactions).transaction_type == "buy"

      {:ok, sells} = PaperTrading.list_transactions(user.id, portfolio.id, %{"type" => "sell"})
      assert length(sells.transactions) == 1
      assert hd(sells.transactions).transaction_type == "sell"
    end
  end

  describe "get_transaction/3" do
    test "returns a single transaction", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Single Tx"})

      {:ok, %{transaction: tx}} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 5},
          price_fetcher: price_fetcher("150"))

      assert {:ok, fetched} = PaperTrading.get_transaction(user.id, portfolio.id, tx.id)
      assert fetched.id == tx.id
      assert fetched.ticker == "AAPL"
    end

    test "returns not_found for non-existent transaction", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "No Tx"})

      assert {:error, :not_found} =
               PaperTrading.get_transaction(user.id, portfolio.id, Ecto.UUID.generate())
    end

    test "returns not_found for another user's portfolio", %{user: user} do
      {:ok, other} =
        Accounts.register_user(%{
          "email" => "other_tx@example.com",
          "password" => "password123",
          "username" => "other_tx"
        })

      {:ok, portfolio} = PaperTrading.create_portfolio(other.id, %{"name" => "Other's"})

      assert {:error, :not_found} =
               PaperTrading.get_transaction(user.id, portfolio.id, Ecto.UUID.generate())
    end
  end

  describe "get_performance/3" do
    test "returns zero metrics for empty portfolio", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Empty Perf"})

      {:ok, perf} = PaperTrading.get_performance(user.id, portfolio.id)

      assert Decimal.equal?(perf.total_value, Decimal.new("100000"))
      assert Decimal.equal?(perf.total_return, Decimal.new("0"))
      assert Decimal.equal?(perf.win_rate, Decimal.new("0"))
      assert perf.total_trades == 0
      assert perf.best_trade == nil
      assert perf.worst_trade == nil
      assert perf.most_traded_ticker == nil
    end

    test "computes unrealized gains", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Unrealized"})

      {:ok, _} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("170"))

      {:ok, perf} =
        PaperTrading.get_performance(user.id, portfolio.id,
          price_fetcher: price_fetcher_for_holdings(%{"AAPL" => "180"})
        )

      # holdings_value = 10 * 180 = 1800; cash = 100000 - 1700 = 98300
      assert Decimal.equal?(perf.holdings_value, Decimal.new("1800"))
      assert Decimal.equal?(perf.total_value, Decimal.new("100100"))
      assert Decimal.gt?(perf.total_return, Decimal.new("0"))
      # unrealized = (180 - 170) * 10 = 100
      assert Decimal.equal?(perf.unrealized_gains, Decimal.new("100"))
    end

    test "computes realized gains and win rate", %{user: user} do
      {:ok, portfolio} = PaperTrading.create_portfolio(user.id, %{"name" => "Realized"})

      {:ok, _} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "AAPL", "side" => "buy", "quantity" => 10},
          price_fetcher: price_fetcher("170"))

      {:ok, _} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "AAPL", "side" => "sell", "quantity" => 5},
          price_fetcher: price_fetcher("180"))

      {:ok, _} =
        PaperTrading.execute_trade(user.id, portfolio.id,
          %{"ticker" => "AAPL", "side" => "sell", "quantity" => 5},
          price_fetcher: price_fetcher("165"))

      {:ok, perf} =
        PaperTrading.get_performance(user.id, portfolio.id,
          price_fetcher: price_fetcher_for_holdings(%{"AAPL" => "170"})
        )

      assert perf.total_sells == 2
      # sell at 180: profit; sell at 165: loss
      assert perf.profitable_sells == 1
      assert Decimal.equal?(perf.win_rate, Decimal.new("50"))
      assert perf.best_trade != nil
      assert perf.worst_trade != nil
      assert perf.most_traded_ticker == "AAPL"
      assert perf.total_trades == 3
    end
  end
end
