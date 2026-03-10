defmodule DungeonCaster.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :location_type, :string, null: false
      add :region, :string
      add :parent_location_id, :string
      add :map_id, :string
      add :faction_ids, :string, default: "[]"
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end
  end
end
