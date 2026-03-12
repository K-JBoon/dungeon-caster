defmodule DungeonCasterWeb.EntityBrowserLiveTest do
  use DungeonCasterWeb.ConnCase
  import Phoenix.LiveViewTest
  alias DungeonCaster.Entities
  alias DungeonCaster.Repo

  setup do
    Entities.upsert_entity("npc", %{
      "id" => "browser-test-npc",
      "name" => "Browser Test NPC",
      "status" => "alive",
      "role" => "guard",
      "tags" => [],
      "faction_ids" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/browser-test-npc.md"
    })

    Entities.upsert_entity("audio", %{
      "id" => "browser-test-audio",
      "name" => "Browser Test Audio",
      "category" => "ambient",
      "asset_path" => "audio/assets/browser-test-track.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/browser-test-audio.md"
    })

    :ok
  end

  test "renders entity list for type", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/npc")
    assert html =~ "Browser Test NPC"
  end

  test "live-updates when entity is upserted via PubSub", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/entities/npc")
    Entities.upsert_entity("npc", %{
      "id" => "pubsub-test-npc",
      "name" => "PubSub NPC",
      "status" => "alive",
      "role" => "guard",
      "tags" => [],
      "faction_ids" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/pubsub-test-npc.md"
    })
    Phoenix.PubSub.broadcast(DungeonCaster.PubSub, "entities:npc", {:updated, "pubsub-test-npc"})
    assert render(view) =~ "PubSub NPC"
  end

  test "renders audio cards with category and asset filename", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/audio")

    assert html =~ "Browser Test Audio"
    assert html =~ "ambient"
    assert html =~ "browser-test-track.mp3"
  end

  test "audio search stays scoped to audio entities", %{conn: conn} do
    Entities.upsert_entity("location", %{
      "id" => "shared-search-location",
      "name" => "Browser Test Audio Archive",
      "location_type" => "landmark",
      "tags" => [],
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/shared-search-location.md"
    })

    Ecto.Adapters.SQL.query!(
      Repo,
      """
      INSERT INTO entities_fts(entity_type, entity_id, name, tags, body_raw)
      VALUES (?, ?, ?, '', '')
      """,
      ["audio", "browser-test-audio", "Browser Test Audio"]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      """
      INSERT INTO entities_fts(entity_type, entity_id, name, tags, body_raw)
      VALUES (?, ?, ?, '', '')
      """,
      ["location", "shared-search-location", "Browser Test Audio Archive"]
    )

    {:ok, view, _html} = live(conn, "/entities/audio")

    view
    |> form("form", %{"q" => "Browser"})
    |> render_change()

    assert_patch(view, "/entities/audio?q=Browser")

    html = render(view)

    assert html =~ "Browser Test Audio"
    refute html =~ "Browser Test NPC"
    refute html =~ "Browser Test Audio Archive"
    refute html =~ "/entities/audio/browser-test-npc"
    refute html =~ "/entities/audio/shared-search-location"
  end

  test "audio search still returns audio hits when global search is saturated by other types", %{
    conn: conn
  } do
    for index <- 1..55 do
      id = "saturated-location-#{index}"
      name = "Saturated Search #{index}"

      Entities.upsert_entity("location", %{
        "id" => id,
        "name" => name,
        "location_type" => "landmark",
        "tags" => [],
        "body_raw" => "",
        "body_html" => "",
        "file_path" => "/tmp/#{id}.md"
      })

      Ecto.Adapters.SQL.query!(
        Repo,
        """
        INSERT INTO entities_fts(entity_type, entity_id, name, tags, body_raw)
        VALUES (?, ?, ?, '', '')
        """,
        ["location", id, name]
      )
    end

    Entities.upsert_entity("audio", %{
      "id" => "saturated-audio",
      "name" => "Hidden Theme",
      "category" => "ambient",
      "asset_path" => "audio/assets/saturated-audio.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/saturated-audio.md"
    })

    Ecto.Adapters.SQL.query!(
      Repo,
      """
      INSERT INTO entities_fts(entity_type, entity_id, name, tags, body_raw)
      VALUES (?, ?, '', '', ?)
      """,
      ["audio", "saturated-audio", "Saturated Search cue in body"]
    )

    {:ok, view, _html} = live(conn, "/entities/audio")

    view
    |> form("form", %{"q" => "Saturated Search"})
    |> render_change()

    assert_patch(view, "/entities/audio?q=Saturated%20Search")

    html = render(view)

    assert html =~ "Hidden Theme"
    refute html =~ "saturated-location-1"
  end

  test "audio search ignores punctuation-only queries without crashing", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/entities/audio")

    view
    |> form("form", %{"q" => "!!!"})
    |> render_change()

    assert_patch(view, "/entities/audio?q=!!!")

    html = render(view)

    assert html =~ "No audio entities yet."
    refute html =~ "Browser Test Audio"
  end

  test "audio PubSub refresh keeps the active audio search filter", %{conn: conn} do
    Ecto.Adapters.SQL.query!(
      Repo,
      """
      INSERT INTO entities_fts(entity_type, entity_id, name, tags, body_raw)
      VALUES (?, ?, ?, '', '')
      """,
      ["audio", "browser-test-audio", "Browser Test Audio"]
    )

    {:ok, view, _html} = live(conn, "/entities/audio?q=Browser")

    assert render(view) =~ "Browser Test Audio"

    Entities.upsert_entity("audio", %{
      "id" => "unrelated-audio",
      "name" => "Campfire Loop",
      "category" => "ambient",
      "asset_path" => "audio/assets/campfire-loop.mp3",
      "body_raw" => "",
      "body_html" => "",
      "file_path" => "/tmp/unrelated-audio.md"
    })

    Phoenix.PubSub.broadcast(DungeonCaster.PubSub, "entities:audio", {:updated, "unrelated-audio"})

    html = render(view)

    assert html =~ "Browser Test Audio"
    refute html =~ "Campfire Loop"
    assert has_element?(view, "input[name=q][value=\"Browser\"]")
  end
end
