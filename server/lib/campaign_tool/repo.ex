defmodule CampaignTool.Repo do
  use Ecto.Repo,
    otp_app: :campaign_tool,
    adapter: Ecto.Adapters.SQLite3
end
