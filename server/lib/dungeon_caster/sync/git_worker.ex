defmodule DungeonCaster.Sync.GitWorker do
  use GenServer
  require Logger

  @debounce_ms 300_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{timer: nil}, name: __MODULE__)
  end

  @doc "Schedule a git commit (debounced — batches all changes in the next 5s window)."
  def schedule do
    GenServer.cast(__MODULE__, :schedule)
  end

  @doc "Immediately run git add -A, commit, and push for the given directory."
  def git_commit(dir) do
    ssh_key = Application.get_env(:dungeon_caster, :ssh_key_path)
    env = build_env(ssh_key)

    with {_, 0} <- System.cmd("git", ["add", "-A"], cd: dir, env: env, stderr_to_stdout: true),
         {_, 0} <- System.cmd("git", ["diff", "--cached", "--quiet"], cd: dir, env: env) do
      # Nothing staged — nothing to commit
      Logger.debug("GitWorker: nothing to commit in #{dir}")
      :ok
    else
      # git diff --cached --quiet exits 1 when there ARE staged changes
      # OR git add failed
      _ ->
        case System.cmd("git", ["commit", "-m", "Dungeon Caster auto-save"],
               cd: dir,
               env: env,
               stderr_to_stdout: true
             ) do
          {_, 0} ->
            Logger.info("GitWorker: committed changes in #{dir}")
            push(dir, env)
            :ok

          {output, code} ->
            Logger.warning("GitWorker: commit failed (#{code}): #{String.trim(output)}")
            :ok
        end
    end
  end

  # GenServer callbacks

  def init(state), do: {:ok, state}

  def handle_cast(:schedule, %{timer: timer} = state) do
    if timer, do: Process.cancel_timer(timer)
    ref = Process.send_after(self(), :commit, @debounce_ms)
    {:noreply, %{state | timer: ref}}
  end

  def handle_info(:commit, state) do
    campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir)
    git_commit(campaign_dir)
    {:noreply, %{state | timer: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private

  defp build_env(nil), do: []

  defp build_env(ssh_key_path) do
    [{"GIT_SSH_COMMAND", "ssh -i #{ssh_key_path} -o StrictHostKeyChecking=no -o BatchMode=yes"}]
  end

  defp push(dir, env) do
    case System.cmd("git", ["push"], cd: dir, env: env, stderr_to_stdout: true) do
      {_, 0} ->
        Logger.info("GitWorker: pushed to remote")

      {output, code} ->
        Logger.debug("GitWorker: push skipped or failed (#{code}): #{String.trim(output)}")
    end
  end
end
