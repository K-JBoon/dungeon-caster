defmodule CampaignTool.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CampaignToolWeb.Telemetry,
      CampaignTool.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:campaign_tool, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:campaign_tool, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CampaignTool.PubSub},
      {Registry, keys: :unique, name: CampaignTool.Session.Registry},
      CampaignTool.Sync.Supervisor,
      # Start to serve requests, typically the last entry
      CampaignToolWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CampaignTool.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CampaignToolWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
