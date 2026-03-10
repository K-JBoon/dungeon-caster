defmodule DungeonCasterWeb.ReceiverController do
  use DungeonCasterWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
