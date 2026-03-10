defmodule StockAnalysis.PaperTrading do
  alias StockAnalysis.Repo
  alias StockAnalysis.PaperTrading.{Portfolio, Holding, Transaction}
  alias StockAnalysis.Stocks

  import Ecto.Query

  @max_quantity Decimal.new("10000")
  @min_quantity Decimal.new("1")

  def create_portfolio(user_id, attrs) do
    %Portfolio{}
    |> Portfolio.create_changeset(attrs, user_id)
    |> Repo.insert()
  end

  def list_portfolios(user_id) do
    from(p in Portfolio,
      where: p.user_id == ^user_id and p.is_active == true,
      preload: [:holdings],
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end

  def get_portfolio(user_id, portfolio_id) do
    case Repo.one(
           from(p in Portfolio,
             where: p.id == ^portfolio_id and p.user_id == ^user_id,
             preload: [:holdings]
           )
         ) do
      nil -> {:error, :not_found}
      portfolio -> {:ok, portfolio}
    end
  end

  def update_portfolio(user_id, portfolio_id, attrs) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id) do
      portfolio
      |> Portfolio.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_portfolio(user_id, portfolio_id) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id) do
      Repo.delete(portfolio)
    end
  end

  @doc """
  Executes a paper trade (buy or sell) against a portfolio.

  Accepts an optional `:price_fetcher` in `opts` — a function `(ticker -> {:ok, %{price: _}} | {:error, _})`
  used to resolve the current price. Defaults to `Stocks.get_overview/1`.

  Returns `{:ok, %{transaction: tx, portfolio: portfolio}}` or `{:error, reason}`.
  """
  def execute_trade(user_id, portfolio_id, params, opts \\ []) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id),
         {:ok, ticker} <- validate_ticker(params),
         {:ok, side} <- validate_side(params),
         {:ok, quantity} <- validate_quantity(params),
         {:ok, price} <- fetch_price(ticker, opts) do
      total_amount = Decimal.mult(price, quantity)
      existing_holding = find_holding(portfolio, ticker)

      with :ok <- validate_trade_feasibility(side, quantity, total_amount, portfolio, existing_holding) do
        do_execute_trade(portfolio, ticker, side, quantity, price, total_amount, existing_holding)
      end
    end
  end

  defp validate_ticker(params) do
    ticker =
      (params["ticker"] || params[:ticker] || "")
      |> to_string()
      |> String.trim()
      |> String.upcase()

    if ticker == "", do: {:error, :invalid_ticker}, else: {:ok, ticker}
  end

  defp validate_side(params) do
    case to_string(params["side"] || params[:side] || "") do
      "buy" -> {:ok, "buy"}
      "sell" -> {:ok, "sell"}
      _ -> {:error, :invalid_side}
    end
  end

  defp validate_quantity(params) do
    raw = params["quantity"] || params[:quantity]

    quantity =
      case raw do
        q when is_integer(q) -> Decimal.new(q)
        q when is_float(q) -> Decimal.from_float(q)
        %Decimal{} = d -> d
        q when is_binary(q) -> parse_decimal_strict(q)
        _ -> nil
      end

    cond do
      is_nil(quantity) -> {:error, :invalid_quantity}
      Decimal.lt?(quantity, @min_quantity) -> {:error, :invalid_quantity}
      Decimal.gt?(quantity, @max_quantity) -> {:error, :invalid_quantity}
      true -> {:ok, quantity}
    end
  end

  defp parse_decimal_strict(str) do
    case Decimal.parse(str) do
      {d, ""} -> d
      _ -> nil
    end
  end

  defp fetch_price(ticker, opts) do
    price_fetcher = Keyword.get(opts, :price_fetcher)

    result =
      if price_fetcher do
        price_fetcher.(ticker)
      else
        Stocks.get_overview(ticker)
      end

    case result do
      {:ok, %{price: price}} when is_binary(price) ->
        case Decimal.parse(price) do
          {d, _} -> {:ok, d}
          :error -> {:error, :price_unavailable}
        end

      {:ok, %{price: %Decimal{} = price}} ->
        {:ok, price}

      {:ok, %{price: price}} when is_number(price) ->
        {:ok, Decimal.new("#{price}")}

      _ ->
        {:error, :price_unavailable}
    end
  end

  defp find_holding(portfolio, ticker) do
    Enum.find(portfolio.holdings, fn h -> String.upcase(h.ticker) == ticker end)
  end

  defp validate_trade_feasibility("buy", _quantity, total_amount, portfolio, _holding) do
    if Decimal.gte?(portfolio.cash_balance, total_amount) do
      :ok
    else
      {:error, :insufficient_funds}
    end
  end

  defp validate_trade_feasibility("sell", _quantity, _total_amount, _portfolio, nil) do
    {:error, :insufficient_shares}
  end

  defp validate_trade_feasibility("sell", quantity, _total_amount, _portfolio, holding) do
    if Decimal.gte?(holding.quantity, quantity) do
      :ok
    else
      {:error, :insufficient_shares}
    end
  end

  defp do_execute_trade(portfolio, ticker, side, quantity, price, total_amount, existing_holding) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :transaction,
      Transaction.create_changeset(
        %Transaction{},
        %{
          ticker: ticker,
          transaction_type: side,
          quantity: quantity,
          price_per_share: price,
          total_amount: total_amount,
          executed_at: now
        },
        portfolio.id
      )
    )
    |> holding_operation(side, portfolio, ticker, quantity, price, total_amount, existing_holding, now)
    |> Ecto.Multi.update(:portfolio, fn _changes ->
      cash_change = if side == "buy", do: Decimal.negate(total_amount), else: total_amount
      new_cash = Decimal.add(portfolio.cash_balance, cash_change)
      Ecto.Changeset.change(portfolio, cash_balance: new_cash)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{transaction: tx, portfolio: updated_portfolio}} ->
        updated_portfolio = Repo.preload(updated_portfolio, :holdings, force: true)
        {:ok, %{transaction: tx, portfolio: updated_portfolio}}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp holding_operation(multi, "buy", portfolio, ticker, quantity, price, total_amount, nil, now) do
    Ecto.Multi.insert(
      multi,
      :holding,
      Holding.create_changeset(
        %Holding{},
        %{
          ticker: ticker,
          quantity: quantity,
          average_cost: price,
          total_cost: total_amount,
          last_updated: now
        },
        portfolio.id
      )
    )
  end

  defp holding_operation(multi, "buy", _portfolio, _ticker, quantity, _price, total_amount, existing, now) do
    new_qty = Decimal.add(existing.quantity, quantity)
    new_total_cost = Decimal.add(existing.total_cost, total_amount)
    new_avg = Decimal.div(new_total_cost, new_qty)

    Ecto.Multi.update(
      multi,
      :holding,
      Holding.update_changeset(existing, %{
        quantity: new_qty,
        average_cost: new_avg,
        total_cost: new_total_cost,
        last_updated: now
      })
    )
  end

  defp holding_operation(multi, "sell", _portfolio, _ticker, quantity, _price, _total_amount, existing, now) do
    new_qty = Decimal.sub(existing.quantity, quantity)

    if Decimal.equal?(new_qty, Decimal.new("0")) do
      Ecto.Multi.delete(multi, :holding, existing)
    else
      new_total_cost = Decimal.mult(new_qty, existing.average_cost)

      Ecto.Multi.update(
        multi,
        :holding,
        Holding.update_changeset(existing, %{
          quantity: new_qty,
          total_cost: new_total_cost,
          last_updated: now
        })
      )
    end
  end
end
