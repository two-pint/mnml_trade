defmodule StockAnalysis.AgentAnalysis.LLMAdapter do
  @moduledoc """
  Behaviour for LLM providers. Key is passed per call (from user settings).
  """
  @callback complete(
              provider :: String.t(),
              api_key :: String.t(),
              prompt :: String.t(),
              options :: keyword()
            ) :: {:ok, String.t()} | {:error, term()}
end
