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

  test "GET /receiver hides the map image until a map is selected", %{conn: conn} do
    conn = get(conn, "/receiver")
    html = html_response(conn, 200)

    assert html =~ ~s(<img id="map-img" alt="" hidden>)
    refute html =~ ~s(<img id="map-img" src="")
  end
end
