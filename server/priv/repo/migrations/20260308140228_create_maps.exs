defmodule CampaignTool.Repo.Migrations.CreateMaps do
  use Ecto.Migration

  def change do
    create table(:maps, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :map_type, :string, null: false
      add :asset_path, :string, null: false
      add :width_px, :integer
      add :height_px, :integer
      add :scale, :string
      add :location_id, :string
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end
  end
end
