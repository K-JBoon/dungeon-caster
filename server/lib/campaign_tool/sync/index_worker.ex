defmodule CampaignTool.Sync.IndexWorker do
  use GenServer
  require Logger
  alias CampaignTool.{Sync.Parser, Entities, Repo}

  @debounce_ms 300

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{timers: %{}}, name: __MODULE__)
  end

  @doc "Schedule indexing of a file path (debounced)."
  def schedule(path) do
    GenServer.cast(__MODULE__, {:schedule, path})
  end

  @doc "Immediately index a file (used in tests and by schedule/1 after debounce)."
  def index_file(path) do
    case Parser.parse_file(path) do
      {:ok, type, data} ->
        with {:ok, _entity} <- Entities.upsert_entity(type, data) do
          update_fts(type, data)
          Phoenix.PubSub.broadcast(
            CampaignTool.PubSub,
            "entities:#{type}",
            {:updated, data["id"]}
          )
        end
        :ok

      {:error, reason} ->
        Logger.warning("IndexWorker: failed to parse #{path}: #{inspect(reason)}")
        :ok
    end
  end

  # GenServer callbacks

  def init(state), do: {:ok, state}

  def handle_cast({:schedule, path}, %{timers: timers} = state) do
    if ref = Map.get(timers, path), do: Process.cancel_timer(ref)
    ref = Process.send_after(self(), {:index, path}, @debounce_ms)
    {:noreply, %{state | timers: Map.put(timers, path, ref)}}
  end

  def handle_info({:index, path}, %{timers: timers} = state) do
    index_file(path)
    {:noreply, %{state | timers: Map.delete(timers, path)}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private

  defp update_fts(type, data) do
    id = data["id"]
    Repo.query!(
      "DELETE FROM entities_fts WHERE entity_type = ? AND entity_id = ?",
      [type, id]
    )
    Repo.query!(
      "INSERT INTO entities_fts(entity_type, entity_id, name, tags, body_raw) VALUES (?,?,?,?,?)",
      [
        type,
        id,
        data["name"] || "",
        (data["tags"] || []) |> Jason.encode!(),
        data["body_raw"] || ""
      ]
    )
  end
end
