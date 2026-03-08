defmodule CampaignTool.Sync.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      CampaignTool.Sync.IndexWorker,
      CampaignTool.Sync.GitWorker,
      CampaignTool.Sync.FileWatcher
    ]
    # rest_for_one: if FileWatcher crashes, restart IndexWorker and GitWorker too
    # Order matters: workers start before watcher so watcher can call them
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
