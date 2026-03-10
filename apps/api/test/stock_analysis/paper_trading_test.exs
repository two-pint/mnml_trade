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
end
