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
end
