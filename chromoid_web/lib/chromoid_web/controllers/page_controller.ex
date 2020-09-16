defmodule ChromoidWeb.PageController do
  use ChromoidWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
