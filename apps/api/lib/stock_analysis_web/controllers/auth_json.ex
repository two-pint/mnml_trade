defmodule StockAnalysisWeb.AuthJSON do
  alias StockAnalysis.Accounts.User

  def auth(%{user: user, token: token, refresh_token: refresh_token}) do
    %{
      token: token,
      refresh_token: refresh_token,
      user: user_data(user)
    }
  end

  defp user_data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      email_verified: user.email_verified
    }
  end
end
