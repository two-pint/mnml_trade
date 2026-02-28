defmodule StockAnalysisWeb.HealthControllerTest do
  use StockAnalysisWeb.ConnCase

  test "GET /api/health returns 200 with status ok", %{conn: conn} do
    conn = get(conn, ~p"/api/health")

    assert json_response(conn, 200) == %{"status" => "ok"}
  end
end
