defmodule StockAnalysisWeb.AuthController do
  use StockAnalysisWeb, :controller

  alias StockAnalysis.Accounts

  action_fallback StockAnalysisWeb.FallbackController

  def register(conn, %{"email" => _, "password" => _} = params) do
    with {:ok, user} <- Accounts.register_user(params),
         {:ok, token, _claims} <- Accounts.issue_token(user),
         {:ok, refresh_token, _claims} <- Accounts.issue_refresh_token(user) do
      conn
      |> put_status(:created)
      |> render(:auth, user: user, token: token, refresh_token: refresh_token)
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_error", message: "email and password are required"})
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_by_email_password(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Accounts.issue_token(user)
        {:ok, refresh_token, _claims} = Accounts.issue_refresh_token(user)

        conn
        |> put_status(:ok)
        |> render(:auth, user: user, token: token, refresh_token: refresh_token)

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_credentials", message: "Invalid email or password"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_error", message: "email and password are required"})
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Accounts.refresh_access_token(refresh_token) do
      {:ok, new_token} ->
        conn
        |> put_status(:ok)
        |> json(%{token: new_token})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", message: "Invalid or expired refresh token"})
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_error", message: "refresh_token is required"})
  end

  def forgot_password(conn, %{"email" => email}) do
    case Accounts.generate_password_reset_token(email) do
      {:ok, _token, _claims} ->
        # TODO: send email with reset link once mailer is configured
        conn |> put_status(:ok) |> json(%{message: "If that email exists, a reset link has been sent"})

      {:ok, :noop} ->
        conn |> put_status(:ok) |> json(%{message: "If that email exists, a reset link has been sent"})
    end
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_error", message: "email is required"})
  end

  def reset_password(conn, %{"token" => token, "password" => password}) do
    case Accounts.reset_password(token, password) do
      {:ok, _user} ->
        conn |> put_status(:ok) |> json(%{message: "Password has been reset"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: StockAnalysisWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid_token", message: "Invalid or expired reset token"})
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_error", message: "token and password are required"})
  end
end
