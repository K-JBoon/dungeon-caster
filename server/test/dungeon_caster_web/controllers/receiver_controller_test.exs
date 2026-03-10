defmodule DungeonCasterWeb.ReceiverControllerTest do
  use DungeonCasterWeb.ConnCase

  test "GET /receiver renders HTML page", %{conn: conn} do
    conn = get(conn, "/receiver")
    assert html_response(conn, 200) =~ "Campaign Receiver"
  end

  test "GET /receiver includes session channel JS", %{conn: conn} do
    conn = get(conn, "/receiver")
    assert html_response(conn, 200) =~ "session:live:"
  end
end
