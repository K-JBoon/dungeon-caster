defmodule CampaignTool.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add :id, :string, primary_key: true
      add :title, :string, null: false
      add :session_number, :integer, null: false
      add :status, :string, null: false
      add :scheduled_date, :string
      add :actual_date, :string
      add :duration_hours, :float
      add :location_ids, :string, default: "[]"
      add :npc_ids, :string, default: "[]"
      add :map_ids, :string, default: "[]"
      add :stat_block_ids, :string, default: "[]"
      add :faction_ids, :string, default: "[]"
      add :xp_awarded, :integer
      add :loot_summary, :string
      add :scenes, :text, default: "[]"
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end
  end
end
