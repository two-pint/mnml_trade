defmodule StockAnalysisWeb.Plugs.CorsTest do
  use StockAnalysisWeb.ConnCase, async: true

  test "OPTIONS preflight from allowed origin returns CORS headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:3000")
      |> put_req_header("access-control-request-method", "POST")
      |> put_req_header("access-control-request-headers", "authorization, content-type")
      |> options(~p"/api/auth/login")

    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
    allowed = List.first(get_resp_header(conn, "access-control-allow-methods"))
    assert String.contains?(allowed, "POST")
  end

  test "response from allowed origin includes CORS headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:3000")
      |> get(~p"/api/health")

    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:3000"]
  end

  test "response from disallowed origin has no CORS headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://evil.com")
      |> get(~p"/api/health")

    assert get_resp_header(conn, "access-control-allow-origin") == []
  end
end
