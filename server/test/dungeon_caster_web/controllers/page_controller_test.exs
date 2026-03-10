defmodule DungeonCasterWeb.PageControllerTest do
  use DungeonCasterWeb.ConnCase

  test "GET /health returns ok", %{conn: conn} do
    conn = get(conn, "/health")
    assert response(conn, 200) == "ok"
  end
end
