defmodule StockAnalysis.Accounts.UserLLMSettings do
  @moduledoc """
  Context for per-user LLM provider settings (BYOK).
  Stores provider, encrypted API key, and optional model; never exposes raw key via API.
  """
  alias StockAnalysis.Repo
  alias StockAnalysis.Accounts.UserLlmSetting
  alias StockAnalysis.AgentAnalysis.Encryption

  @allowed_providers ~w(openai anthropic)

  def get_settings(user_id) do
    case Repo.get_by(UserLlmSetting, user_id: user_id) do
      nil -> {:error, :not_found}
      s -> {:ok, %{provider: s.provider, model: s.model, api_key_configured: true}}
    end
  end

  def put_settings(user_id, attrs) do
    api_key = attrs["api_key"] || attrs[:api_key]
    provider = normalize_provider(attrs["provider"] || attrs[:provider])
    model = attrs["model"] || attrs[:model]

    if is_nil(provider) or provider == "" do
      {:error, :invalid_provider}
    else
      if api_key && api_key != "" do
        case Encryption.encrypt(api_key) do
          {:ok, encrypted} ->
            attrs = %{
              user_id: user_id,
              provider: provider,
              encrypted_api_key: encrypted,
              model: model
            }

            case Repo.get_by(UserLlmSetting, user_id: user_id) do
              nil ->
                %UserLlmSetting{}
                |> UserLlmSetting.changeset(attrs)
                |> Repo.insert()

              existing ->
                existing
                |> UserLlmSetting.changeset(attrs)
                |> Repo.update()
            end
            |> case do
              {:ok, s} -> {:ok, %{provider: s.provider, model: s.model, api_key_configured: true}}
              err -> err
            end

          {:error, _} ->
            {:error, :encryption_failed}
        end
      else
        # Allow updating provider/model only (clear key not supported via this path)
        case Repo.get_by(UserLlmSetting, user_id: user_id) do
          nil -> {:error, :api_key_required}
          existing ->
            update_attrs = %{provider: provider, model: model}
            existing
            |> Ecto.Changeset.cast(update_attrs, [:provider, :model])
            |> Ecto.Changeset.validate_required([:provider])
            |> Ecto.Changeset.validate_inclusion(:provider, @allowed_providers)
            |> Repo.update()
            |> case do
              {:ok, s} -> {:ok, %{provider: s.provider, model: s.model, api_key_configured: true}}
              err -> err
            end
        end
      end
    end
  end

  def get_decrypted_key(user_id) do
    case Repo.get_by(UserLlmSetting, user_id: user_id) do
      nil -> {:error, :not_found}
      s -> Encryption.decrypt(s.encrypted_api_key)
    end
  end

  @doc """
  Returns provider, decrypted api_key, and model for the agent pipeline.
  Used only internally; never expose via HTTP.
  """
  def get_credentials(user_id) do
    case Repo.get_by(UserLlmSetting, user_id: user_id) do
      nil -> {:error, :not_found}
      s ->
        case Encryption.decrypt(s.encrypted_api_key) do
          {:ok, api_key} -> {:ok, %{provider: s.provider, api_key: api_key, model: s.model}}
          err -> err
        end
    end
  end

  defp normalize_provider(nil), do: nil
  defp normalize_provider(p) when is_binary(p), do: String.downcase(String.trim(p))
  defp normalize_provider(_), do: nil
end
