defmodule DungeonCaster.Entities.Schemas.Faction do
  use Ecto.Schema
  import Ecto.Changeset
  alias DungeonCaster.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "factions" do
    field :name, :string
    field :status, :string
    field :alignment, :string
    field :headquarters_id, :string
    field :leader_id, :string
    field :member_ids, StringList
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(faction, attrs) do
    faction
    |> cast(attrs, [
      :id, :name, :status, :alignment, :headquarters_id, :leader_id,
      :member_ids, :tags, :body_raw, :body_html, :file_path
    ])
    |> validate_required([:id, :name, :status])
  end
end
