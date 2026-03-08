defmodule CampaignTool.Sync.GitWorker do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{timer: nil}, name: __MODULE__)
  end

  def schedule do
    GenServer.cast(__MODULE__, :schedule)
  end

  def init(state), do: {:ok, state}
  def handle_cast(:schedule, state), do: {:noreply, state}
  def handle_info(_msg, state), do: {:noreply, state}
end
