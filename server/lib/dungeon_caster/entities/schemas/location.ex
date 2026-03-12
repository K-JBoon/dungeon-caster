defmodule DungeonCaster.Entities.Schemas.Location do
  use Ecto.Schema
  import Ecto.Changeset
  alias DungeonCaster.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "locations" do
    field :name, :string
    field :location_type, :string
    field :region, :string
    field :parent_location_id, :string
    field :map_id, :string
    field :faction_ids, StringList
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(location, attrs) do
    location
    |> cast(attrs, [
      :id,
      :name,
      :location_type,
      :region,
      :parent_location_id,
      :map_id,
      :faction_ids,
      :tags,
      :body_raw,
      :body_html,
      :file_path
    ])
    |> validate_required([:id, :name, :location_type])
  end
end
