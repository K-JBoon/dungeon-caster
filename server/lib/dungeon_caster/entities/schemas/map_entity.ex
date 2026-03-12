defmodule DungeonCaster.Entities.Schemas.MapEntity do
  use Ecto.Schema
  import Ecto.Changeset
  alias DungeonCaster.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "maps" do
    field :name, :string
    field :map_type, :string
    field :asset_path, :string
    field :width_px, :integer
    field :height_px, :integer
    field :scale, :string
    field :location_id, :string
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(map_entity, attrs) do
    map_entity
    |> cast(attrs, [
      :id,
      :name,
      :map_type,
      :asset_path,
      :width_px,
      :height_px,
      :scale,
      :location_id,
      :tags,
      :body_raw,
      :body_html,
      :file_path
    ])
    |> validate_required([:id, :name, :map_type, :asset_path])
  end
end
