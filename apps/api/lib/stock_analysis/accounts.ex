defmodule StockAnalysis.Accounts do
  alias StockAnalysis.Repo
  alias StockAnalysis.Accounts.User
  alias StockAnalysis.Guardian

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_id(id) do
    Repo.get(User, id)
  end

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def authenticate_by_email_password(email, password) do
    user = get_user_by_email(email)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  def issue_token(user) do
    Guardian.encode_and_sign(user, %{}, token_type: "access")
  end

  def issue_refresh_token(user) do
    Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :day})
  end

  def refresh_access_token(refresh_token) do
    with {:ok, _old_stuff, {new_token, _new_claims}} <-
           Guardian.refresh(refresh_token, ttl: {1, :hour}) do
      {:ok, new_token}
    end
  end

  def verify_token(token) do
    Guardian.resource_from_token(token)
  end

  def generate_password_reset_token(email) do
    case get_user_by_email(email) do
      nil -> {:ok, :noop}
      user -> Guardian.encode_and_sign(user, %{}, token_type: "reset", ttl: {15, :minute})
    end
  end

  def reset_password(token, new_password) do
    with {:ok, user, %{"typ" => "reset"}} <- Guardian.resource_from_token(token) do
      user
      |> User.password_changeset(%{"password" => new_password})
      |> Repo.update()
    else
      {:ok, _user, _claims} -> {:error, :invalid_token_type}
      error -> error
    end
  end
end
