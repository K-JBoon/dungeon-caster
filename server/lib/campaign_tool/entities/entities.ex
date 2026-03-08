defmodule CampaignTool.Entities do
  import Ecto.Query
  alias CampaignTool.Repo
  alias CampaignTool.Entities.Schemas.Npc
  alias CampaignTool.Entities.Schemas.Location
  alias CampaignTool.Entities.Schemas.Faction
  alias CampaignTool.Entities.Schemas.Session
  alias CampaignTool.Entities.Schemas.StatBlock
  alias CampaignTool.Entities.Schemas.MapEntity

  @schema_map %{
    "npc" => Npc,
    "location" => Location,
    "faction" => Faction,
    "session" => Session,
    "stat-block" => StatBlock,
    "map" => MapEntity
  }

  def schema_for(type), do: Map.fetch!(@schema_map, type)

  def list_entities(type, opts \\ []) do
    schema = schema_for(type)

    from(e in schema)
    |> maybe_filter_tag(opts[:tag])
    |> maybe_filter_status(opts[:status])
    |> Repo.all()
  end

  def get_entity!(type, id) do
    Repo.get!(schema_for(type), id)
  end

  def get_entity(type, id) do
    Repo.get(schema_for(type), id)
  end

  def upsert_entity(type, attrs) do
    schema = schema_for(type)
    cs = struct(schema) |> schema.changeset(attrs)

    Repo.insert(cs,
      on_conflict: {:replace_all_except, [:inserted_at]},
      conflict_target: :id
    )
  end

  def delete_entity(type, id) do
    case Repo.get(schema_for(type), id) do
      nil -> :ok
      entity -> Repo.delete(entity) |> elem(0)
    end
  end

  def search(query_string) when is_binary(query_string) and byte_size(query_string) > 0 do
    safe = String.replace(query_string, ~r/[^a-zA-Z0-9\s]/, "") <> "*"

    result =
      Repo.query!(
        "SELECT entity_type, entity_id, name FROM entities_fts WHERE entities_fts MATCH ? ORDER BY rank LIMIT 50",
        [safe]
      )

    Enum.map(result.rows, fn [type, id, name] -> %{type: type, id: id, name: name} end)
  end

  def search(_), do: []

  defp maybe_filter_tag(query, nil), do: query

  defp maybe_filter_tag(query, tag) do
    where(query, [e], like(e.tags, ^"%#{tag}%"))
  end

  defp maybe_filter_status(query, nil), do: query

  defp maybe_filter_status(query, status) do
    where(query, [e], e.status == ^status)
  end
end
