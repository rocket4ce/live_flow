defmodule FlotasWeb.DocsController do
  use FlotasWeb, :controller

  @valid_pages ~w(quick-start core-concepts nodes edges viewport state advanced reference)

  @page_titles %{
    "quick-start" => "Quick Start",
    "core-concepts" => "Core Concepts",
    "nodes" => "Nodes",
    "edges" => "Edges & Handles",
    "viewport" => "Viewport & Controls",
    "state" => "State Management",
    "advanced" => "Advanced Features",
    "reference" => "Reference"
  }

  def index(conn, _params) do
    redirect(conn, to: ~p"/docs/quick-start")
  end

  def show(conn, %{"page" => page}) when page in @valid_pages do
    template = page |> String.replace("-", "_") |> String.to_existing_atom()

    render(conn, template,
      page_title: @page_titles[page] <> " · LiveFlow Docs",
      current_page: page
    )
  end

  def show(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(FlotasWeb.ErrorHTML)
    |> render(:"404")
  end
end
