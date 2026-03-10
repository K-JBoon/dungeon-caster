defmodule DungeonCaster.Entities.Schemas.Session do
  use Ecto.Schema
  import Ecto.Changeset
  alias DungeonCaster.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "sessions" do
    field :title, :string
    field :session_number, :integer
    field :status, :string
    field :scheduled_date, :string
    field :actual_date, :string
    field :duration_hours, :float
    field :location_ids, StringList
    field :npc_ids, StringList
    field :map_ids, StringList
    field :stat_block_ids, StringList
    field :faction_ids, StringList
    field :xp_awarded, :integer
    field :loot_summary, :string
    field :scenes, :string
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(session, attrs) do
    attrs = case Map.get(attrs, "scenes") do
      scenes when is_list(scenes) -> Map.put(attrs, "scenes", Jason.encode!(scenes))
      _ -> attrs
    end

    session
    |> cast(attrs, [
      :id, :title, :session_number, :status, :scheduled_date, :actual_date,
      :duration_hours, :location_ids, :npc_ids, :map_ids, :stat_block_ids,
      :faction_ids, :xp_awarded, :loot_summary, :scenes, :tags,
      :body_raw, :body_html, :file_path
    ])
    |> validate_required([:id, :title, :session_number, :status])
  end
end
