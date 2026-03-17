defmodule StockAnalysis.Integrations.Finnhub do
  @moduledoc """
  Finnhub API integration for company news.

  API key is configured via application env or `FINNHUB_API_KEY` (never hard-coded).
  Free tier: 60 requests/minute.
  """
  require Logger

  @default_base_url "https://finnhub.io/api/v1"

  defp base_url do
    Application.get_env(:stock_analysis, :finnhub_base_url, @default_base_url)
  end

  @doc """
  Fetches recent news articles for a ticker (last 7 days).

  Returns `{:ok, [%{headline: _, summary: _, source: _, datetime: _, url: _, sentiment_from_source: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_news(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))
    today = Date.utc_today()
    from = Date.add(today, -7) |> Date.to_iso8601()
    to = Date.to_iso8601(today)

    case get("/company-news", symbol: ticker, from: from, to: to) do
      {:ok, articles} when is_list(articles) ->
        {:ok, Enum.map(articles, &normalize_article/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp api_key do
    Application.get_env(:stock_analysis, :finnhub_api_key) ||
      System.get_env("FINNHUB_API_KEY")
  end

  defp get(path, extra_params) do
    key = api_key()

    if is_nil(key) or key == "" do
      Logger.warning("Finnhub: API key not configured")
      {:error, :api_key_missing}
    else
      url = base_url() <> path

      params =
        [{:token, key} | extra_params]
        |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

      opts = [
        params: params,
        receive_timeout: 10_000,
        retry: Application.get_env(:stock_analysis, :req_retry, :transient)
      ]

      case Req.get(url, opts) do
        {:ok, %{status: 200, body: body}} ->
          parsed = maybe_decode_json(body)

          cond do
            is_list(parsed) -> {:ok, parsed}
            is_map(parsed) and Map.has_key?(parsed, "error") -> {:error, :not_found}
            true -> {:error, :invalid_response}
          end

        {:ok, %{status: 429}} ->
          {:error, :rate_limit}

        {:ok, %{status: 403}} ->
          {:error, :api_key_missing}

        {:ok, %{status: status}} when status >= 500 ->
          {:error, :server_error}

        {:ok, _} ->
          {:error, :invalid_response}

        {:error, _} ->
          {:error, :server_error}
      end
    end
  end

  defp maybe_decode_json(body) when is_list(body), do: body
  defp maybe_decode_json(body) when is_map(body), do: body

  defp maybe_decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end

  defp maybe_decode_json(_), do: nil

  defp normalize_article(raw) when is_map(raw) do
    %{
      headline: raw["headline"],
      summary: raw["summary"],
      source: raw["source"],
      datetime: raw["datetime"],
      url: raw["url"],
      sentiment_from_source: raw["sentiment"]
    }
  end

  defp normalize_article(_), do: nil
end
