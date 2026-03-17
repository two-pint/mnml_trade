defmodule StockAnalysis.AgentAnalysis.LLM.Anthropic do
  @moduledoc """
  Anthropic Messages API adapter. Uses passed-in api_key (BYOK).
  """
  @behaviour StockAnalysis.AgentAnalysis.LLMAdapter

  @default_model "claude-3-5-haiku-20241022"
  @default_max_tokens 1024
  @timeout_ms 30_000
  @url "https://api.anthropic.com/v1/messages"
  @version "2023-06-01"

  @impl true
  def complete(_provider, api_key, prompt, options) when is_binary(api_key) and is_binary(prompt) do
    model = Keyword.get(options, :model, @default_model)
    max_tokens = Keyword.get(options, :max_tokens, @default_max_tokens)

    body = %{
      model: model,
      max_tokens: max_tokens,
      messages: [%{role: "user", content: prompt}]
    }

    case Req.post(@url,
           body: Jason.encode!(body),
           headers: [
             {"x-api-key", api_key},
             {"anthropic-version", @version},
             {"Content-Type", "application/json"}
           ],
           receive_timeout: @timeout_ms
         ) do
      {:ok, %{status: 200, body: resp_body}} ->
        case extract_text_from_content(resp_body) do
          nil -> {:error, :empty_response}
          text when is_binary(text) -> {:ok, String.trim(text)}
          _ -> {:error, :empty_response}
        end

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

  defp extract_text_from_content(%{"content" => blocks}) when is_list(blocks), do: first_text_block(blocks)
  defp extract_text_from_content(%{content: blocks}) when is_list(blocks), do: first_text_block(blocks)

  defp extract_text_from_content(_), do: nil

  defp first_text_block(blocks) do
    Enum.find_value(blocks, fn
      %{"type" => "text", "text" => t} when is_binary(t) -> t
      %{type: "text", text: t} when is_binary(t) -> t
      _ -> nil
    end)
  end
end
