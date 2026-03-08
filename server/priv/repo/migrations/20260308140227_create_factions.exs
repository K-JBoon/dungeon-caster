defmodule CampaignTool.Repo.Migrations.CreateFactions do
  use Ecto.Migration

  def change do
    create table(:factions, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false
      add :alignment, :string
      add :headquarters_id, :string
      add :leader_id, :string
      add :member_ids, :string, default: "[]"
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end
  end
end
