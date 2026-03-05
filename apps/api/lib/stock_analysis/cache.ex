defmodule StockAnalysis.Cache do
  @moduledoc """
  ETS-backed cache with TTL support.

  Key convention: `scope:ticker:data_type` (e.g. `"stocks:AAPL:price"`).

  Default TTLs per data type (configurable): price 15s, technical 1h, institutional 1h.
  """
  use GenServer

  @table_name :stock_analysis_cache
  @default_ttls %{
    price: 15,
    technical: 3600,
    institutional: 3600
  }

  ## Public start_link for supervision

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## Client API

  @doc """
  Returns the value for `key`, or `nil` if missing or expired.
  Expired entries are removed lazily on get.
  """
  def get(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Stores `value` under `key` with TTL of `ttl_seconds`.
  """
  def put(key, value, ttl_seconds) when is_binary(key) and is_integer(ttl_seconds) and ttl_seconds > 0 do
    GenServer.call(__MODULE__, {:put, key, value, ttl_seconds})
  end

  @doc """
  Deletes the entry for `key`.
  """
  def delete(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  @doc """
  Returns whether `key` exists and is not expired.
  """
  def exists?(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:exists?, key})
  end

  @doc """
  Builds a cache key from scope, ticker, and data type.
  """
  def key(scope, ticker, data_type) do
    "#{scope}:#{ticker}:#{data_type}"
  end

  @doc """
  Returns the default TTL in seconds for a data type (e.g. `:price`, `:technical`, `:institutional`).
  """
  def default_ttl(data_type) do
    Application.get_env(:stock_analysis, :cache_default_ttls, @default_ttls)
    |> Map.get(data_type, 3600)
  end

  ## GenServer callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    result =
      case :ets.lookup(state.table, key) do
        [{^key, value, expires_at}] ->
          if System.system_time(:second) < expires_at do
            value
          else
            :ets.delete(state.table, key)
            nil
          end
        [] ->
          nil
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:put, key, value, ttl_seconds}, _from, state) do
    expires_at = System.system_time(:second) + ttl_seconds
    :ets.insert(state.table, {key, value, expires_at})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete, key}, _from, state) do
    :ets.delete(state.table, key)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:exists?, key}, _from, state) do
    result =
      case :ets.lookup(state.table, key) do
        [{^key, _value, expires_at}] -> System.system_time(:second) < expires_at
        [] -> false
      end

    {:reply, result, state}
  end
end
