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
    # rest_for_one: if IndexWorker or GitWorker crashes, FileWatcher (listed after
    # them) is also restarted — ensuring FileWatcher never runs with a dead worker.
    # Order matters: workers start before watcher so watcher can call them.
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
