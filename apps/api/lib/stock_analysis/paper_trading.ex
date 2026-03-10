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

  # ---------------------------------------------------------------------------
  # M4-004: Holdings and transaction history
  # ---------------------------------------------------------------------------

  @doc """
  Returns holdings for a portfolio, each enriched with current_price, current_value,
  gain_loss, and gain_loss_percent. Accepts `:price_fetcher` in opts for testing.
  """
  def list_holdings(user_id, portfolio_id, opts \\ []) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id) do
      enriched =
        Enum.map(portfolio.holdings, fn holding ->
          enrich_holding(holding, opts)
        end)

      {:ok, enriched}
    end
  end

  defp enrich_holding(holding, opts) do
    {current_price, price_available} =
      case fetch_price(holding.ticker, opts) do
        {:ok, p} -> {p, true}
        _ -> {Decimal.new("0"), false}
      end

    current_value = Decimal.mult(holding.quantity, current_price)
    cost_basis = holding.total_cost

    {gain_loss, gain_loss_percent} =
      if price_available do
        gl = Decimal.sub(current_value, cost_basis)

        gl_pct =
          if Decimal.gt?(cost_basis, Decimal.new("0")) do
            Decimal.mult(Decimal.div(gl, cost_basis), Decimal.new("100"))
          else
            Decimal.new("0")
          end

        {gl, gl_pct}
      else
        {Decimal.new("0"), Decimal.new("0")}
      end

    %{
      holding: holding,
      current_price: current_price,
      current_value: current_value,
      gain_loss: gain_loss,
      gain_loss_percent: gain_loss_percent
    }
  end

  @doc """
  Lists transactions for a portfolio with pagination and optional filters.

  Options:
    - `:page` — page number (default 1)
    - `:per_page` — items per page (default 20, max 100)
    - `:ticker` — filter by ticker
    - `:type` — filter by "buy" or "sell"
    - `:from` — filter executed_at >= date (ISO 8601 string)
    - `:to` — filter executed_at <= date (ISO 8601 string)
  """
  def list_transactions(user_id, portfolio_id, opts \\ %{}) do
    with {:ok, _portfolio} <- get_portfolio(user_id, portfolio_id) do
      page = max(parse_int(opts["page"] || opts[:page], 1), 1)
      per_page = min(max(parse_int(opts["per_page"] || opts[:per_page], 20), 1), 100)
      offset = (page - 1) * per_page

      base_query =
        from(t in Transaction,
          where: t.portfolio_id == ^portfolio_id,
          order_by: [desc: t.executed_at, desc: t.inserted_at]
        )

      filtered_query =
        base_query
        |> maybe_filter_ticker(opts)
        |> maybe_filter_type(opts)
        |> maybe_filter_from(opts)
        |> maybe_filter_to(opts)

      total_count = Repo.aggregate(filtered_query, :count)

      transactions =
        filtered_query
        |> limit(^per_page)
        |> offset(^offset)
        |> Repo.all()

      {:ok,
       %{
         transactions: transactions,
         page: page,
         per_page: per_page,
         total_count: total_count,
         total_pages: ceil(total_count / per_page)
       }}
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(_, default), do: default

  defp maybe_filter_ticker(query, opts) do
    case opts["ticker"] || opts[:ticker] do
      nil -> query
      "" -> query
      ticker -> where(query, [t], t.ticker == ^String.upcase(ticker))
    end
  end

  defp maybe_filter_type(query, opts) do
    case opts["type"] || opts[:type] do
      nil -> query
      "" -> query
      type when type in ["buy", "sell"] -> where(query, [t], t.transaction_type == ^type)
      _ -> query
    end
  end

  defp maybe_filter_from(query, opts) do
    case opts["from"] || opts[:from] do
      nil ->
        query

      from_str when is_binary(from_str) ->
        case DateTime.from_iso8601(from_str) do
          {:ok, dt, _} -> where(query, [t], t.executed_at >= ^dt)
          _ -> case Date.from_iso8601(from_str) do
            {:ok, d} -> where(query, [t], t.executed_at >= ^DateTime.new!(d, ~T[00:00:00]))
            _ -> query
          end
        end

      _ ->
        query
    end
  end

  defp maybe_filter_to(query, opts) do
    case opts["to"] || opts[:to] do
      nil ->
        query

      to_str when is_binary(to_str) ->
        case DateTime.from_iso8601(to_str) do
          {:ok, dt, _} -> where(query, [t], t.executed_at <= ^dt)
          _ -> case Date.from_iso8601(to_str) do
            {:ok, d} -> where(query, [t], t.executed_at <= ^DateTime.new!(d, ~T[23:59:59]))
            _ -> query
          end
        end

      _ ->
        query
    end
  end

  @doc """
  Returns a single transaction, scoped by user ownership of the portfolio.
  """
  def get_transaction(user_id, portfolio_id, transaction_id) do
    with {:ok, _portfolio} <- get_portfolio(user_id, portfolio_id) do
      case Repo.one(
             from(t in Transaction,
               where: t.id == ^transaction_id and t.portfolio_id == ^portfolio_id
             )
           ) do
        nil -> {:error, :not_found}
        tx -> {:ok, tx}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # M4-005: Performance metrics
  # ---------------------------------------------------------------------------

  @doc """
  Computes portfolio performance metrics. Accepts `:price_fetcher` in opts for testing.
  """
  def get_performance(user_id, portfolio_id, opts \\ []) do
    with {:ok, portfolio} <- get_portfolio(user_id, portfolio_id) do
      transactions =
        from(t in Transaction,
          where: t.portfolio_id == ^portfolio_id,
          order_by: [desc: t.executed_at]
        )
        |> Repo.all()

      holdings_value =
        Enum.reduce(portfolio.holdings, Decimal.new("0"), fn h, acc ->
          case fetch_price(h.ticker, opts) do
            {:ok, price} -> Decimal.add(acc, Decimal.mult(h.quantity, price))
            _ -> Decimal.add(acc, h.total_cost)
          end
        end)

      total_value = Decimal.add(portfolio.cash_balance, holdings_value)

      total_return =
        if Decimal.gt?(portfolio.starting_balance, Decimal.new("0")) do
          Decimal.mult(
            Decimal.div(
              Decimal.sub(total_value, portfolio.starting_balance),
              portfolio.starting_balance
            ),
            Decimal.new("100")
          )
        else
          Decimal.new("0")
        end

      unrealized_gains =
        Enum.reduce(portfolio.holdings, Decimal.new("0"), fn h, acc ->
          case fetch_price(h.ticker, opts) do
            {:ok, price} ->
              gain = Decimal.mult(Decimal.sub(price, h.average_cost), h.quantity)
              Decimal.add(acc, gain)

            _ ->
              acc
          end
        end)

      sells = Enum.filter(transactions, fn t -> t.transaction_type == "sell" end)

      avg_cost_by_ticker = compute_avg_costs(transactions)

      sell_gains =
        Enum.map(sells, fn t ->
          avg_cost = Map.get(avg_cost_by_ticker, t.ticker, t.price_per_share)
          gain_per_share = Decimal.sub(t.price_per_share, avg_cost)
          total_gain = Decimal.mult(gain_per_share, t.quantity)
          pct = if Decimal.gt?(avg_cost, Decimal.new("0")) do
            Decimal.mult(Decimal.div(gain_per_share, avg_cost), Decimal.new("100"))
          else
            Decimal.new("0")
          end
          %{transaction: t, gain: total_gain, pct: pct}
        end)

      realized_gains =
        Enum.reduce(sell_gains, Decimal.new("0"), fn sg, acc -> Decimal.add(acc, sg.gain) end)

      profitable_sells = Enum.count(sell_gains, fn sg -> Decimal.gt?(sg.gain, Decimal.new("0")) end)
      total_sells = length(sells)

      win_rate =
        if total_sells > 0 do
          Decimal.mult(
            Decimal.div(Decimal.new(profitable_sells), Decimal.new(total_sells)),
            Decimal.new("100")
          )
        else
          Decimal.new("0")
        end

      best_trade = Enum.max_by(sell_gains, fn sg -> sg.pct end, fn -> nil end)
      worst_trade = Enum.min_by(sell_gains, fn sg -> sg.pct end, fn -> nil end)

      total_trades = length(transactions)

      most_traded_ticker =
        if total_trades > 0 do
          transactions
          |> Enum.group_by(fn t -> t.ticker end)
          |> Enum.max_by(fn {_ticker, txs} -> length(txs) end)
          |> elem(0)
        else
          nil
        end

      {:ok,
       %{
         total_value: total_value,
         cash_balance: portfolio.cash_balance,
         holdings_value: holdings_value,
         total_return: total_return,
         realized_gains: realized_gains,
         unrealized_gains: unrealized_gains,
         best_trade: format_trade_metric(best_trade),
         worst_trade: format_trade_metric(worst_trade),
         win_rate: win_rate,
         total_trades: total_trades,
         total_sells: total_sells,
         profitable_sells: profitable_sells,
         most_traded_ticker: most_traded_ticker
       }}
    end
  end

  defp compute_avg_costs(transactions) do
    zero = Decimal.new("0")

    transactions
    |> Enum.filter(fn t -> t.transaction_type == "buy" end)
    |> Enum.reduce(%{}, fn t, acc ->
      {old_qty, old_total} = Map.get(acc, t.ticker, {zero, zero})
      new_qty = Decimal.add(old_qty, t.quantity)
      new_total = Decimal.add(old_total, t.total_amount)
      Map.put(acc, t.ticker, {new_qty, new_total})
    end)
    |> Map.new(fn {ticker, {qty, total}} ->
      avg = if Decimal.gt?(qty, zero), do: Decimal.div(total, qty), else: zero
      {ticker, avg}
    end)
  end

  defp format_trade_metric(nil), do: nil

  defp format_trade_metric(%{transaction: tx, gain: gain, pct: pct}) do
    %{
      id: tx.id,
      ticker: tx.ticker,
      quantity: tx.quantity,
      price_per_share: tx.price_per_share,
      gain: gain,
      gain_percent: pct,
      executed_at: tx.executed_at
    }
  end
end
