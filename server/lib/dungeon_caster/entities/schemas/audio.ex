defmodule DungeonCaster.Entities.Schemas.Audio do
  use Ecto.Schema
  import Ecto.Changeset
  alias DungeonCaster.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "audio" do
    field :name, :string
    field :category, :string
    field :asset_path, :string
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(audio, attrs) do
    audio
    |> cast(attrs, [:id, :name, :category, :asset_path, :tags, :body_raw, :body_html, :file_path])
    |> validate_required([:id, :name, :category, :asset_path])
  end
end
