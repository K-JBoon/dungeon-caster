defmodule CampaignTool.Repo.Migrations.CreateStatBlocks do
  use Ecto.Migration

  def change do
    create table(:stat_blocks, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :cr, :string
      add :size, :string
      add :creature_type, :string
      add :source, :string
      add :hp, :integer
      add :ac, :integer
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end
  end
end
