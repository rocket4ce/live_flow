defmodule FlotasWeb.Router do
  use FlotasWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FlotasWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FlotasWeb do
    pipe_through :browser

    get "/", PageController, :home

    # LiveFlow Demos
    live "/flow-demo", FlowDemoLive
    live "/flow-forms", FlowFormsLive
    live "/flow-realtime", FlowRealtimeLive
    live "/flow-pipeline", FlowPipelineLive
    live "/flow-custom-nodes", FlowCustomNodesLive
    live "/flow-dynamic-layout", FlowDynamicLayoutLive
    live "/flow-shapes", FlowShapesLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", FlotasWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:flotas, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FlotasWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
