defmodule CampaignToolWeb.EntityDetailLive do
  use CampaignToolWeb, :live_view
  def mount(_params, _session, socket), do: {:ok, socket}
  def render(assigns), do: ~H"<p>Entity detail (stub)</p>"
end
