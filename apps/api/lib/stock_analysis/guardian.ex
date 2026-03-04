defmodule StockAnalysis.Guardian do
  use Guardian, otp_app: :stock_analysis

  alias StockAnalysis.Accounts

  def subject_for_token(%{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :invalid_resource}
  end

  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user_by_id(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_) do
    {:error, :invalid_claims}
  end
end
