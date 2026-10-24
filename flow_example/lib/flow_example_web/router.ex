defmodule FlowExampleWeb.Router do
  use FlowExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FlowExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FlowExampleWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/playground", PlaygroundLive
    live "/interaction", InteractionLive
    live "/edges", EdgesLive
    live "/resizing", ResizingLive
    live "/custom-nodes", CustomNodesLive
    live "/large", LargeLive
    live "/examples", ExamplesLive
  end

  # React Flow examples (generated from FlowExampleWeb.Examples)
  scope "/" do
    pipe_through :browser

    for example <- FlowExampleWeb.Examples.routed() do
      live example.path, example.module
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", FlowExampleWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:flow_example, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FlowExampleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
