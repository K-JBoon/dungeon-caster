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

    # Runner is full-screen — no app layout
    live_session :runner, layout: false do
      live "/sessions/:id/run", SessionRunnerLive
    end

    # All other live views use the sidebar app layout
    live_session :app, layout: {CampaignToolWeb.Layouts, :app} do
      live "/", DashboardLive
      live "/entities/:type", EntityBrowserLive
      live "/entities/:type/new", EntityFormLive
      live "/entities/:type/:id", EntityDetailLive
      live "/entities/:type/:id/edit", EntityFormLive
      live "/entities/:type/:id/edit/raw", EntityEditorLive
      live "/maps/:id", MapViewerLive
      live "/sessions/:id/plan", SessionPlannerLive
    end

    get "/health", HealthController, :index
    get "/receiver", ReceiverController, :index
    get "/sessions/:id/draw", PlayerDrawController, :index
    get "/audio/*path", AudioController, :stream
    get "/maps/assets/*path", MapAssetController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", CampaignToolWeb do
  #   pipe_through :api
  # end
end
