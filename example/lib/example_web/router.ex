defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/flow-demo", FlowDemoLive
    live "/flow-forms", FlowFormsLive
    live "/flow-realtime", FlowRealtimeLive
    live "/flow-pipeline", FlowPipelineLive
    live "/flow-custom-nodes", FlowCustomNodesLive
    live "/flow-dynamic-layout", FlowDynamicLayoutLive
    live "/flow-shapes", FlowShapesLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExampleWeb do
  #   pipe_through :api
  # end
end
