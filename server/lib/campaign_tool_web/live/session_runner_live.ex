defmodule CampaignToolWeb.SessionRunnerLive do
  use CampaignToolWeb, :live_view
  def mount(_params, _session, socket), do: {:ok, socket}
  def render(assigns), do: ~H"<p>Session runner (stub)</p>"
end
