defmodule CampaignToolWeb.Router do
  use CampaignToolWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CampaignToolWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CampaignToolWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/entities/:type", EntityBrowserLive
    live "/entities/:type/:id", EntityDetailLive
    live "/entities/:type/:id/edit", EntityEditorLive
    live "/maps/:id", MapViewerLive
    live "/sessions/:id/plan", SessionPlannerLive
    live "/sessions/:id/run", SessionRunnerLive

    get "/health", HealthController, :index
    get "/receiver", ReceiverController, :index
    get "/audio/*path", AudioController, :stream
  end

  # Other scopes may use custom stacks.
  # scope "/api", CampaignToolWeb do
  #   pipe_through :api
  # end
end
