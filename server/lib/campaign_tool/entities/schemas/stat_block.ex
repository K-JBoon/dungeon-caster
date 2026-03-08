defmodule CampaignTool.Entities.Schemas.StatBlock do
  use Ecto.Schema
  import Ecto.Changeset
  alias CampaignTool.Entities.Types.StringList

  @primary_key {:id, :string, autogenerate: false}
  schema "stat_blocks" do
    field :name, :string
    field :cr, :string
    field :size, :string
    field :creature_type, :string
    field :source, :string
    field :hp, :integer
    field :ac, :integer
    field :tags, StringList
    field :body_raw, :string
    field :body_html, :string
    field :file_path, :string
    timestamps()
  end

  def changeset(stat_block, attrs) do
    stat_block
    |> cast(attrs, [
      :id, :name, :cr, :size, :creature_type, :source, :hp, :ac,
      :tags, :body_raw, :body_html, :file_path
    ])
    |> validate_required([:id, :name])
  end
end
