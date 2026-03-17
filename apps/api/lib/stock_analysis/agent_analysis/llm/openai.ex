defmodule StockAnalysis.AgentAnalysis.LLM.OpenAI do
  @moduledoc """
  OpenAI chat completions adapter. Uses passed-in api_key (BYOK).
  """
  @behaviour StockAnalysis.AgentAnalysis.LLMAdapter

  @default_model "gpt-4o-mini"
  @default_max_tokens 1024
  @timeout_ms 30_000
  @url "https://api.openai.com/v1/chat/completions"

  @impl true
  def complete(_provider, api_key, prompt, options) when is_binary(api_key) and is_binary(prompt) do
    model = Keyword.get(options, :model, @default_model)
    max_tokens = Keyword.get(options, :max_tokens, @default_max_tokens)

    body = %{
      model: model,
      messages: [%{role: "user", content: prompt}],
      max_tokens: max_tokens
    }

    case Req.post(@url,
           body: body,
           headers: [
             {"Authorization", "Bearer #{api_key}"},
             {"Content-Type", "application/json"}
           ],
           receive_timeout: @timeout_ms
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} when is_binary(content) ->
        {:ok, String.trim(content)}

      {:ok, %{status: 200, body: %{"choices" => []}}} ->
        {:error, :empty_response}

      {:ok, %{status: 401}} ->
        {:error, :invalid_api_key}

      {:ok, %{status: 429}} ->
        {:error, :rate_limit}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
