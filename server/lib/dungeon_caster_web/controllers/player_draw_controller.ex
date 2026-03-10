defmodule DungeonCasterWeb.PlayerDrawController do
  use DungeonCasterWeb, :controller

  def index(conn, %{"id" => session_id}) do
    render(conn, :index, session_id: session_id, layout: false)
  end
end
