defmodule CampaignTool.Repo.Migrations.CreateNpcs do
  use Ecto.Migration

  def change do
    create table(:npcs, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false
      add :role, :string, null: false
      add :race, :string
      add :class, :string
      add :level, :integer
      add :location_id, :string
      add :faction_ids, :string, default: "[]"
      add :portrait, :string
      add :stat_block_id, :string
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end
  end
end
