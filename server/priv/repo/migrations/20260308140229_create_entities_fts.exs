defmodule CampaignTool.Repo.Migrations.CreateEntitiesFts do
  use Ecto.Migration

  def up do
    execute """
    CREATE VIRTUAL TABLE entities_fts USING fts5(
      entity_type, entity_id, name, tags, body_raw,
      tokenize='porter unicode61'
    )
    """
  end

  def down do
    execute "DROP TABLE IF EXISTS entities_fts"
  end
end
