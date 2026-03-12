defmodule StockAnalysis.EngagementTest do
  use StockAnalysis.DataCase, async: true

  alias StockAnalysis.Accounts
  alias StockAnalysis.Engagement

  @user_attrs %{
    "email" => "engagement_test@example.com",
    "password" => "password123",
    "username" => "engagement_tester"
  }

  @user2_attrs %{
    "email" => "engagement_test2@example.com",
    "password" => "password123",
    "username" => "engagement_tester2"
  }

  setup do
    {:ok, user} = Accounts.register_user(@user_attrs)
    {:ok, user2} = Accounts.register_user(@user2_attrs)
    %{user: user, user2: user2}
  end

  describe "add_to_watchlist/2" do
    test "adds a ticker to the watchlist", %{user: user} do
      assert {:ok, item} = Engagement.add_to_watchlist(user.id, "AAPL")
      assert item.ticker == "AAPL"
      assert item.user_id == user.id
      assert item.added_at
    end

    test "upcases and trims ticker", %{user: user} do
      assert {:ok, item} = Engagement.add_to_watchlist(user.id, " aapl ")
      assert item.ticker == "AAPL"
    end

    test "duplicate add is idempotent", %{user: user} do
      {:ok, first} = Engagement.add_to_watchlist(user.id, "AAPL")
      {:ok, second} = Engagement.add_to_watchlist(user.id, "AAPL")
      assert first.id == second.id
    end

    test "rejects empty ticker", %{user: user} do
      assert {:error, :invalid_ticker} = Engagement.add_to_watchlist(user.id, "")
      assert {:error, :invalid_ticker} = Engagement.add_to_watchlist(user.id, "   ")
    end

    test "accepts map with ticker key", %{user: user} do
      assert {:ok, item} = Engagement.add_to_watchlist(user.id, %{"ticker" => "MSFT"})
      assert item.ticker == "MSFT"
    end

    test "different users can watch same ticker", %{user: user, user2: user2} do
      {:ok, _} = Engagement.add_to_watchlist(user.id, "TSLA")
      {:ok, _} = Engagement.add_to_watchlist(user2.id, "TSLA")
      assert length(Engagement.list_watchlist(user.id)) == 1
      assert length(Engagement.list_watchlist(user2.id)) == 1
    end
  end

  describe "remove_from_watchlist/2" do
    test "removes a watched ticker", %{user: user} do
      {:ok, _} = Engagement.add_to_watchlist(user.id, "AAPL")
      assert {:ok, :removed} = Engagement.remove_from_watchlist(user.id, "AAPL")
      assert Engagement.list_watchlist(user.id) == []
    end

    test "returns not_found for non-watched ticker", %{user: user} do
      assert {:error, :not_found} = Engagement.remove_from_watchlist(user.id, "NOPE")
    end

    test "cannot remove another user's watchlist item", %{user: user, user2: user2} do
      {:ok, _} = Engagement.add_to_watchlist(user.id, "AAPL")
      assert {:error, :not_found} = Engagement.remove_from_watchlist(user2.id, "AAPL")
      assert length(Engagement.list_watchlist(user.id)) == 1
    end
  end

  describe "list_watchlist/1" do
    test "returns items ordered by added_at DESC", %{user: user} do
      {:ok, _} = Engagement.add_to_watchlist(user.id, "AAPL")
      Process.sleep(10)
      {:ok, _} = Engagement.add_to_watchlist(user.id, "MSFT")
      Process.sleep(10)
      {:ok, _} = Engagement.add_to_watchlist(user.id, "TSLA")

      items = Engagement.list_watchlist(user.id)
      tickers = Enum.map(items, & &1.ticker)
      assert tickers == ["TSLA", "MSFT", "AAPL"]
    end

    test "returns empty list for new user", %{user: user} do
      assert Engagement.list_watchlist(user.id) == []
    end

    test "scoped to user", %{user: user, user2: user2} do
      {:ok, _} = Engagement.add_to_watchlist(user.id, "AAPL")
      {:ok, _} = Engagement.add_to_watchlist(user2.id, "MSFT")

      assert [%{ticker: "AAPL"}] = Engagement.list_watchlist(user.id)
      assert [%{ticker: "MSFT"}] = Engagement.list_watchlist(user2.id)
    end
  end

  describe "record_view/2" do
    test "records a view", %{user: user} do
      assert :ok = Engagement.record_view(user.id, "AAPL")
      history = Engagement.list_history(user.id)
      assert length(history) == 1
      assert hd(history).ticker == "AAPL"
    end

    test "records multiple views of different tickers", %{user: user} do
      Engagement.record_view(user.id, "AAPL")
      Engagement.record_view(user.id, "MSFT")
      Engagement.record_view(user.id, "TSLA")

      history = Engagement.list_history(user.id)
      assert length(history) == 3
    end

    test "handles empty ticker gracefully", %{user: user} do
      assert :ok = Engagement.record_view(user.id, "")
      assert Engagement.list_history(user.id) == []
    end
  end

  describe "list_history/2" do
    test "returns entries ordered by viewed_at DESC", %{user: user} do
      Engagement.record_view(user.id, "AAPL")
      Process.sleep(10)
      Engagement.record_view(user.id, "MSFT")
      Process.sleep(10)
      Engagement.record_view(user.id, "TSLA")

      history = Engagement.list_history(user.id)
      tickers = Enum.map(history, & &1.ticker)
      assert tickers == ["TSLA", "MSFT", "AAPL"]
    end

    test "respects limit parameter", %{user: user} do
      for t <- ["A", "B", "C", "D", "E"] do
        Engagement.record_view(user.id, t)
      end

      assert length(Engagement.list_history(user.id, 3)) == 3
    end

    test "prunes history beyond 20 entries", %{user: user} do
      for i <- 1..25 do
        Engagement.record_view(user.id, "T#{i}")
      end

      history = Engagement.list_history(user.id)
      assert length(history) == 20
    end

    test "scoped to user", %{user: user, user2: user2} do
      Engagement.record_view(user.id, "AAPL")
      Engagement.record_view(user2.id, "MSFT")

      assert [%{ticker: "AAPL"}] = Engagement.list_history(user.id)
      assert [%{ticker: "MSFT"}] = Engagement.list_history(user2.id)
    end
  end
end
