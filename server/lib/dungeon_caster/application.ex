defmodule DungeonCaster.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DungeonCasterWeb.Telemetry,
      DungeonCaster.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:dungeon_caster, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:dungeon_caster, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DungeonCaster.PubSub},
      {Registry, keys: :unique, name: DungeonCaster.Session.Registry},
      DungeonCaster.Sync.Supervisor,
      # Start to serve requests, typically the last entry
      DungeonCasterWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DungeonCaster.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DungeonCasterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
