defmodule DungeonCaster.Repo.Migrations.CreateAudioEntities do
  use Ecto.Migration

  def change do
    create table(:audio, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :category, :string, null: false
      add :asset_path, :string, null: false
      add :tags, :string, default: "[]"
      add :body_raw, :text
      add :body_html, :text
      add :file_path, :string
      timestamps()
    end

    create index(:audio, [:category])
  end
end
