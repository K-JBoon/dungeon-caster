defmodule DungeonCasterWeb.PageController do
  use DungeonCasterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
