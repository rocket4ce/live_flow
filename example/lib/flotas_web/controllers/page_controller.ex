defmodule FlotasWeb.PageController do
  use FlotasWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
