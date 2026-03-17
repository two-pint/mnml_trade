defmodule StockAnalysis.AgentAnalysis do
  @moduledoc """
  Multi-agent LLM pipeline: Technical Analyst, Institutional Analyst,
  Researchers (bull/bear), Synthesis. Uses current user's LLM credentials (BYOK).
  Results cached per ticker with TTL.
  """
  alias StockAnalysis.AgentAnalysis.LLM
  alias StockAnalysis.Analysis
  alias StockAnalysis.Cache
  alias StockAnalysis.InstitutionalActivity
  alias StockAnalysis.Accounts.UserLLMSettings
  alias StockAnalysis.Stocks

  @max_summary_chars 2000
  @consideration_allowlist ~w(Worth a look Neutral Caution Avoid Strong buy Strong sell)

  @doc """
  Returns cached agent analysis for the ticker or runs the full pipeline with the
  given user's credentials. Caches result under agent_analysis:{ticker}.

  Returns:
  - `{:ok, result}` — result has summary, consideration?, technical_summary?, institutional_summary?, bull_points?, bear_points?, cached_at?
  - `{:error, :llm_not_configured}` — user has not set API key in settings (API should return 403)
  - `{:error, reason}` — pipeline or LLM failure
  """
  def get_or_compute(ticker, user_id) when is_binary(ticker) do
    ticker = String.upcase(String.trim(ticker))

    with {:ok, credentials} <- UserLLMSettings.get_credentials(user_id),
         {:ok, result} <- get_or_run_pipeline(ticker, credentials) do
      {:ok, result}
    else
      {:error, :not_found} -> {:error, :llm_not_configured}
      err -> err
    end
  end

  defp get_or_run_pipeline(ticker, credentials) do
    cache_key = Cache.key("agent_analysis", ticker, "full")
    ttl = Cache.default_ttl(:agent_analysis)

    case Cache.get(cache_key) do
      nil ->
        run_pipeline(ticker, credentials)
        |> case do
          {:ok, result} ->
            cached = Map.put(result, :cached_at, DateTime.utc_now() |> DateTime.to_iso8601())
            Cache.put(cache_key, cached, ttl)
            {:ok, cached}

          err ->
            err
        end

      cached ->
        {:ok, cached}
    end
  end

  defp run_pipeline(ticker, credentials) do
    overview = safe_fetch(fn -> Stocks.get_overview(ticker) end)
    technical = safe_fetch(fn -> Analysis.get_technical(ticker) end)
    institutional = safe_fetch(fn -> InstitutionalActivity.get_basic(ticker) end)

    with {:ok, technical_summary} <- run_technical_analyst(ticker, overview, technical, credentials),
         {:ok, institutional_summary} <- run_institutional_analyst(ticker, institutional, credentials),
         {:ok, debate} <- run_researchers(technical_summary, institutional_summary, credentials),
         {:ok, synthesis} <- run_synthesis(technical_summary, institutional_summary, debate, credentials) do
      {:ok,
       %{
         summary: synthesis.summary,
         consideration: synthesis.consideration,
         technical_summary: technical_summary,
         institutional_summary: institutional_summary,
         bull_points: debate.bull,
         bear_points: debate.bear
       }}
    end
  end

  defp run_technical_analyst(ticker, overview, technical, credentials) do
    prompt = build_technical_prompt(ticker, overview, technical)
    opts = llm_opts(credentials)
    case LLM.complete(credentials.provider, credentials.api_key, prompt, opts) do
      {:ok, text} -> {:ok, sanitize_summary(text)}
      {:error, _} = err -> err
    end
  end

  defp run_institutional_analyst(ticker, institutional, credentials) do
    if institutional == nil do
      {:ok, "No recent institutional data available for this ticker."}
    else
      prompt = build_institutional_prompt(ticker, institutional)
      opts = llm_opts(credentials)
      case LLM.complete(credentials.provider, credentials.api_key, prompt, opts) do
        {:ok, text} -> {:ok, sanitize_summary(text)}
        {:error, _} = err -> err
      end
    end
  end

  defp run_researchers(technical_summary, institutional_summary, credentials) do
    combined = """
    Technical analysis summary:
    #{technical_summary}

    Institutional / options flow summary:
    #{institutional_summary}
    """

    prompt = """
    Based only on the following analyst summaries for a stock, list key points.

    #{combined}

    Respond with exactly two sections:
    BULL POINTS:
    - (2-4 short bullet points supporting a bullish view)

    BEAR POINTS:
    - (2-4 short bullet points supporting a bearish view)

    Use only the data provided. No preamble.
    """

    opts = llm_opts(credentials)
    case LLM.complete(credentials.provider, credentials.api_key, prompt, opts) do
      {:ok, text} ->
        {bull, bear} = parse_bull_bear(text)
        {:ok, %{bull: bull, bear: bear}}

      {:error, _} = err ->
        err
    end
  end

  defp run_synthesis(technical_summary, institutional_summary, debate, credentials) do
    prompt = """
    Given the following analysis:

    Technical: #{technical_summary}

    Institutional: #{institutional_summary}

    Bull points: #{Enum.join(debate.bull, " ")}

    Bear points: #{Enum.join(debate.bear, " ")}

    Write one short paragraph (2-4 sentences) summarizing the overall view. Then on a new line write ONLY one of these consideration labels: Worth a look, Neutral, Caution, Avoid, Strong buy, Strong sell.

    Do not give investment advice. This is for research only.
    """

    opts = llm_opts(credentials)
    case LLM.complete(credentials.provider, credentials.api_key, prompt, opts) do
      {:ok, text} ->
        {summary, consideration} = parse_synthesis(text)
        {:ok, %{summary: summary, consideration: consideration}}

      {:error, _} = err ->
        err
    end
  end

  defp build_technical_prompt(ticker, overview, technical) do
    price_str = if overview && overview[:price], do: "Price: $#{overview[:price]}. Change: #{overview[:change]}.", else: "Price data unavailable."
    tech_str =
      if technical do
        score = technical[:score] || "—"
        signal = technical[:signal] || "—"
        ind = (technical[:indicators] || %{}) |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end) |> Enum.join(", ")
        "Technical score: #{score}, signal: #{signal}. Indicators: #{ind}."
      else
        "Technical data unavailable."
      end

    """
    Summarize in 2-4 sentences what the technical picture suggests for stock #{ticker}. #{price_str} #{tech_str}
    Do not give buy/sell advice. Research only.
    """
  end

  defp build_institutional_prompt(ticker, inst) do
    flow = (inst[:options_flow] || []) |> Enum.take(5) |> inspect()
    dp = inst[:dark_pool] || %{}
    dp_str = "Dark pool: #{inspect(dp)}."

    """
    Summarize in 2-4 sentences the institutional and options flow picture for #{ticker}. Options flow (sample): #{flow}. #{dp_str}
    Do not give buy/sell advice. Research only.
    """
  end

  defp llm_opts(credentials) do
    opts = [max_tokens: 1024]
    if credentials[:model] && credentials.model != "" do
      Keyword.put(opts, :model, credentials.model)
    else
      opts
    end
  end

  defp sanitize_summary(text) when is_binary(text) do
    text
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, @max_summary_chars)
  end

  defp parse_bull_bear(text) do
    text = text || ""
    parts = String.split(text, ~r/BEAR POINTS:/i, parts: 2)
    bull_section = Enum.at(parts, 0) || ""
    bear_section = if length(parts) > 1, do: Enum.at(parts, 1) || "", else: ""

    bull =
      bull_section
      |> String.replace(~r/^.*?BULL POINTS:\s*/is, "")
      |> String.split(~r/\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn s -> String.replace(s, ~r/^[-*]\s*/, "") |> String.trim() end)
      |> Enum.take(6)

    bear =
      bear_section
      |> String.split(~r/\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn s -> String.replace(s, ~r/^[-*]\s*/, "") |> String.trim() end)
      |> Enum.take(6)

    {if(bull == [], do: ["—"], else: bull), if(bear == [], do: ["—"], else: bear)}
  end

  defp parse_synthesis(text) do
    text = text || ""
    lines = String.split(text, ~r/\n/, trim: true)
    summary_lines = Enum.take_while(lines, fn line -> not consideration_line?(line) end)
    summary = summary_lines |> Enum.join(" ") |> String.trim() |> String.slice(0, @max_summary_chars)
    consideration =
      lines
      |> Enum.drop(length(summary_lines))
      |> Enum.find_value("Neutral", fn line -> extract_consideration(line) end)

    {if(summary == "", do: "No summary generated.", else: summary), consideration}
  end

  defp consideration_line?(line) do
    line = String.trim(line) |> String.downcase()
    Enum.any?(@consideration_allowlist, fn allowed -> String.contains?(line, String.downcase(allowed)) end)
  end

  defp extract_consideration(line) do
    line = String.trim(line)
    found = Enum.find(@consideration_allowlist, fn allowed -> String.contains?(String.downcase(line), String.downcase(allowed)) end)
    if found, do: found, else: nil
  end

  defp safe_fetch(fun) do
    case fun.() do
      {:ok, v} -> v
      _ -> nil
    end
  end
end
