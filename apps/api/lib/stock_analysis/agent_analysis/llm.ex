defmodule StockAnalysis.AgentAnalysis.LLM do
  @moduledoc """
  Dispatches LLM completion to the configured provider adapter.
  Provider and api_key come from user settings (BYOK).
  """
  @adapters %{
    "openai" => StockAnalysis.AgentAnalysis.LLM.OpenAI,
    "anthropic" => StockAnalysis.AgentAnalysis.LLM.Anthropic
  }

  def complete(provider, api_key, prompt, options \\ [])
      when is_binary(provider) and is_binary(api_key) and is_binary(prompt) do
    provider = String.downcase(provider)

    case Map.get(@adapters, provider) do
      nil -> {:error, :unsupported_provider}
      adapter -> adapter.complete(provider, api_key, prompt, options)
    end
  end
end
