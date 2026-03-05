defmodule StockAnalysis.InstitutionalActivity do
  @moduledoc """
  Context for institutional data: options flow and dark pool.

  Delegates to Unusual Whales integration, caches combined result per ticker (1h TTL),
  and includes `data_as_of` (ISO timestamp). When rate limit is hit, returns cached
  data with `stale: true` instead of failing.
  """
  alias StockAnalysis.Cache
  alias StockAnalysis.Integrations.UnusualWhales

  @doc """
  Fetches basic institutional data for a ticker: options flow + dark pool.

  Uses cache first (1h TTL). On miss, fetches both from Unusual Whales, builds
  payload with `data_as_of` (ISO8601), caches and returns.

  When the integration returns `:rate_limit`, returns any cached data for the ticker
  with `stale: true`; if no cache, returns `{:error, :rate_limit}`.

  Returns `{:ok, %{options_flow: [...], dark_pool: %{}, data_as_of: iso_string, stale?: false}}`
  or `{:ok, %{..., stale?: true}}` when serving stale due to rate limit.
  """
  def get_basic(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    cache_key = Cache.key("institutional", ticker, "basic")
    ttl = Cache.default_ttl(:institutional)

    case Cache.get(cache_key) do
      nil ->
        fetch_and_cache_basic(ticker, cache_key, ttl)

      cached ->
        {:ok, Map.put(cached, :stale, false)}
    end
  end

  defp fetch_and_cache_basic(ticker, cache_key, ttl) do
    with {:ok, flow} <- UnusualWhales.get_options_flow(ticker),
         {:ok, dark_pool} <- UnusualWhales.get_dark_pool(ticker) do
      data_as_of = DateTime.utc_now() |> DateTime.to_iso8601()
      payload = %{
        ticker: ticker,
        options_flow: flow,
        dark_pool: dark_pool,
        data_as_of: data_as_of,
        stale: false
      }

      Cache.put(cache_key, payload, ttl)
      # Keep a stale copy (24h) so we can return it when rate limit is hit
      stale_key = cache_key <> "_stale"
      Cache.put(stale_key, payload, 86_400)
      {:ok, payload}
    else
      {:error, :rate_limit} ->
        stale_key = cache_key <> "_stale"
        case Cache.get(stale_key) do
          nil -> {:error, :rate_limit}
          cached -> {:ok, Map.put(cached, :stale, true)}
        end

      _ ->
        {:error, :not_found}
    end
  end
end
