defmodule FlowExampleWeb.PageController do
  use FlowExampleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
