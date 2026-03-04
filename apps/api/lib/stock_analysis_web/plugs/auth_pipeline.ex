defmodule StockAnalysisWeb.Plugs.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :stock_analysis,
    module: StockAnalysis.Guardian,
    error_handler: StockAnalysisWeb.Plugs.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource, allow_blank: false
end
