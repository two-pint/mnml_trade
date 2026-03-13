defmodule StockAnalysis.AgentAnalysis.Encryption do
  @moduledoc """
  Encrypts and decrypts user LLM API keys at rest using AES-256-GCM.
  Key is loaded from config (LLM_SETTINGS_ENCRYPTION_KEY or derived from secret_key_base).
  Never log or expose decrypted values.
  """
  @aad "stock_analysis_llm_key"
  @tag_len 16
  @iv_len 12
  @key_len 32

  def encrypt(plaintext) when is_binary(plaintext) do
    key = get_key()
    iv = :crypto.strong_rand_bytes(@iv_len)

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, @tag_len, true) do
      {ciphertext, tag} ->
        {:ok, iv <> tag <> ciphertext}

      _ ->
        {:error, :encryption_failed}
    end
  end

  def decrypt(payload) when is_binary(payload) do
    key = get_key()

    if byte_size(payload) < @iv_len + @tag_len do
      {:error, :invalid_payload}
    else
      <<iv::binary-@iv_len, tag::binary-@tag_len, ciphertext::binary>> = payload

      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
        plaintext when is_binary(plaintext) ->
          {:ok, plaintext}

        _ ->
          {:error, :decryption_failed}
      end
    end
  end

  defp get_key do
    case Application.get_env(:stock_analysis, :llm_settings_encryption_key) do
      nil ->
        # Fallback: derive from endpoint secret_key_base (dev/test)
        base =
          Application.get_env(:stock_analysis, StockAnalysisWeb.Endpoint, [])[:secret_key_base] ||
            "dev-llm-encryption-fallback-do-not-use-in-prod"

        :crypto.hash(:sha256, base) |> binary_part(0, @key_len)

      key when is_binary(key) ->
        if byte_size(key) >= @key_len do
          binary_part(key, 0, @key_len)
        else
          :crypto.hash(:sha256, key) |> binary_part(0, @key_len)
        end
    end
  end
end
