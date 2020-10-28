defmodule ChromoidWeb.LayoutView do
  use ChromoidWeb, :view

  def active?(conn, "/") do
    conn.private[:phoenix_controller] == ChromoidWeb.PageController
  end

  def active?(conn, "/devices" <> _) do
    match?({ChromoidWeb.DeviceLive, _}, conn.private[:phoenix_live_view])
  end

  def active?(conn, "/scripts" <> _) do
    match?({ChromoidWeb.ScriptLive, _}, conn.private[:phoenix_live_view]) ||
      conn.private[:phoenix_controller] == ChromoidWeb.ScriptController
  end

  def active?(_conn, _link) do
    false
  end
end
