defmodule StockAnalysis.Integrations.Reddit do
  @moduledoc """
  Reddit integration for fetching recent posts mentioning a stock ticker
  from target subreddits (wallstreetbets, stocks, investing).

  Uses the public Reddit JSON API (no OAuth required for read-only).
  Rate limit: 60 requests/minute (respected via User-Agent and back-off).
  """
  require Logger

  @default_base_url "https://www.reddit.com"
  @target_subreddits ~w(wallstreetbets stocks investing)
  @user_agent "mnml-trade/0.1 (stock-analysis bot)"

  defp base_url do
    Application.get_env(:stock_analysis, :reddit_base_url, @default_base_url)
  end

  @doc """
  Fetches recent posts mentioning `ticker` from target subreddits.

  Returns `{:ok, [%{title: _, body: _, score: _, num_comments: _, subreddit: _, created_utc: _, url: _}, ...]}`
  or `{:error, reason}`.
  """
  def get_posts(ticker) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))

    results =
      @target_subreddits
      |> Enum.reduce([], fn subreddit, acc ->
        case fetch_subreddit(subreddit, ticker) do
          {:ok, posts} -> acc ++ posts
          {:error, _} -> acc
        end
      end)

    {:ok, results}
  end

  defp fetch_subreddit(subreddit, ticker) do
    url = base_url() <> "/r/#{subreddit}/search.json"

    params = [
      {"q", ticker},
      {"sort", "new"},
      {"restrict_sr", "on"},
      {"t", "week"},
      {"limit", "25"}
    ]

    opts = [
      params: params,
      headers: [{"user-agent", @user_agent}],
      receive_timeout: 10_000,
      retry: Application.get_env(:stock_analysis, :req_retry, :transient)
    ]

    case Req.get(url, opts) do
      {:ok, %{status: 200, body: body}} ->
        parsed = maybe_decode_json(body)
        posts = extract_posts(parsed, subreddit)
        {:ok, posts}

      {:ok, %{status: 429}} ->
        Logger.warning("Reddit: rate limited on r/#{subreddit}")
        {:error, :rate_limit}

      {:ok, %{status: status}} when status >= 500 ->
        {:error, :server_error}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, _} ->
        {:error, :server_error}
    end
  end

  defp extract_posts(%{"data" => %{"children" => children}}, subreddit) when is_list(children) do
    Enum.map(children, fn
      %{"data" => post} when is_map(post) ->
        %{
          title: post["title"],
          body: post["selftext"] || "",
          score: post["score"] || 0,
          num_comments: post["num_comments"] || 0,
          subreddit: subreddit,
          created_utc: post["created_utc"],
          url: post["permalink"] && ("https://reddit.com" <> post["permalink"]) || post["url"]
        }

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_posts(_, _), do: []

  defp maybe_decode_json(body) when is_map(body), do: body

  defp maybe_decode_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> parsed
      _ -> nil
    end
  end

  defp maybe_decode_json(_), do: nil
end
