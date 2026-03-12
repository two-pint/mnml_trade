defmodule StockAnalysis.Notifications do
  @moduledoc """
  Context for push notification management: token registration,
  preferences, and sending via Expo Push API.
  """

  import Ecto.Query
  alias StockAnalysis.Repo
  alias StockAnalysis.Notifications.PushToken
  alias StockAnalysis.Accounts.User

  require Logger

  @expo_push_url "https://exp.host/--/api/v2/push/send"

  # --- Push Token Registration ---

  def register_token(user_id, %{"token" => token, "platform" => platform}) do
    case Repo.get_by(PushToken, token: token) do
      %PushToken{user_id: ^user_id} = existing ->
        {:ok, existing}

      %PushToken{} = existing ->
        existing
        |> Ecto.Changeset.change(user_id: user_id)
        |> Repo.update()

      nil ->
        %PushToken{}
        |> PushToken.changeset(%{token: token, platform: platform, user_id: user_id})
        |> Repo.insert()
    end
  end

  def register_token(_user_id, _), do: {:error, :invalid_params}

  def remove_token(user_id, token) when is_binary(token) do
    case Repo.get_by(PushToken, user_id: user_id, token: token) do
      %PushToken{} = pt -> Repo.delete(pt)
      nil -> {:ok, :not_found}
    end
  end

  def remove_all_tokens(user_id) do
    PushToken
    |> where([p], p.user_id == ^user_id)
    |> Repo.delete_all()
  end

  def list_tokens(user_id) do
    PushToken
    |> where([p], p.user_id == ^user_id)
    |> Repo.all()
  end

  # --- Notification Preferences ---

  def get_preferences(user_id) do
    case Repo.get(User, user_id) do
      %User{notification_preferences: prefs} when is_map(prefs) -> {:ok, prefs}
      %User{} -> {:ok, default_preferences()}
      nil -> {:error, :not_found}
    end
  end

  def update_preferences(user_id, prefs) when is_map(prefs) do
    case Repo.get(User, user_id) do
      %User{} = user ->
        merged = Map.merge(user.notification_preferences || default_preferences(), prefs)

        user
        |> Ecto.Changeset.change(notification_preferences: merged)
        |> Repo.update()

      nil ->
        {:error, :not_found}
    end
  end

  defp default_preferences do
    %{"push_enabled" => true, "price_alerts" => true, "whale_alerts" => true}
  end

  # --- Sending Push Notifications ---

  def send_push(user_id, title, body, data \\ %{}) do
    tokens = list_tokens(user_id)

    if Enum.empty?(tokens) do
      Logger.debug("[Notifications] no push tokens for user #{user_id}")
      {:ok, :no_tokens}
    else
      case get_preferences(user_id) do
        {:ok, %{"push_enabled" => false}} ->
          {:ok, :disabled}

        {:ok, _prefs} ->
          messages =
            Enum.map(tokens, fn pt ->
              %{
                to: pt.token,
                title: title,
                body: body,
                data: data,
                sound: "default"
              }
            end)

          send_to_expo(messages)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp send_to_expo(messages) do
    case Req.post(@expo_push_url,
           json: messages,
           headers: [{"accept", "application/json"}, {"content-type", "application/json"}]
         ) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("[Notifications] Expo push sent: #{inspect(body)}")
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[Notifications] Expo push failed status=#{status}: #{inspect(body)}")
        {:error, :push_failed}

      {:error, reason} ->
        Logger.error("[Notifications] Expo push error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
