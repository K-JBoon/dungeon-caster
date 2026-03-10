defmodule DungeonCaster.Entities.Schemas.StatBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  schema "stat_blocks" do
    field :name, :string
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(stat_block, attrs) do
    stat_block
    |> cast(attrs, [:id, :name, :body_raw, :body_html, :file_path])
    |> validate_required([:id, :name])
  end
end
