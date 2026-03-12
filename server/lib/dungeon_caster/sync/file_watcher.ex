defmodule DungeonCaster.Sync.FileWatcher do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir)
    File.mkdir_p!(campaign_dir)

    case FileSystem.start_link(dirs: [campaign_dir]) do
      {:ok, pid} ->
        FileSystem.subscribe(pid)
        Logger.info("FileWatcher: watching #{campaign_dir}")
        {:ok, %{fs_pid: pid}}

      :ignore ->
        Logger.warning(
          "FileWatcher: file_system backend unavailable (inotify-tools missing?), watching disabled"
        )

        {:ok, %{fs_pid: nil}}

      {:error, reason} ->
        Logger.warning(
          "FileWatcher: could not start file_system: #{inspect(reason)}, watching disabled"
        )

        {:ok, %{fs_pid: nil}}
    end
  end

  def handle_info({:file_event, _pid, {path, events}}, state) do
    if should_index?(path, events) do
      DungeonCaster.Sync.IndexWorker.schedule(path)
      DungeonCaster.Sync.GitWorker.schedule()
    end

    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp should_index?(path, events) do
    String.ends_with?(path, ".md") and
      not String.contains?(path, "/.") and
      not String.contains?(path, "~") and
      not Enum.any?(events, &(&1 in [:removed, :deleted]))
  end
end
