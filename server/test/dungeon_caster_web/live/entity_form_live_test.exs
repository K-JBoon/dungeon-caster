defmodule DungeonCasterWeb.EntityFormLiveTest do
  use DungeonCasterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias DungeonCaster.Entities

  setup do
    previous_campaign_dir = Application.get_env(:dungeon_caster, :campaign_dir)

    campaign_dir =
      Path.join(System.tmp_dir!(), "entity-form-live-#{System.unique_integer([:positive])}")

    File.rm_rf!(campaign_dir)
    File.mkdir_p!(Path.join(campaign_dir, "audio"))
    Application.put_env(:dungeon_caster, :campaign_dir, campaign_dir)

    on_exit(fn ->
      File.rm_rf!(campaign_dir)

      if previous_campaign_dir do
        Application.put_env(:dungeon_caster, :campaign_dir, previous_campaign_dir)
      else
        Application.delete_env(:dungeon_caster, :campaign_dir)
      end
    end)

    {:ok, campaign_dir: campaign_dir}
  end

  test "renders audio-specific fields with audio upload accept list", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/entities/audio/new")

    assert html =~ "Category *"
    assert html =~ "ambient"
    assert html =~ "sfx"
    assert html =~ "entity[asset_path]"
    assert html =~ ~s(name="asset")
    assert html =~ ~s(accept=".mp3,.wav,.aac")
  end

  test "creates an audio entity and copies the uploaded asset with a normalized filename", %{
    conn: conn,
    campaign_dir: campaign_dir
  } do
    {:ok, view, _html} = live(conn, "/entities/audio/new")

    upload =
      file_input(view, "form", :asset, [
        %{
          name: "Tavern Theme LOOP!!.MP3",
          content: "fake mp3 data",
          type: "audio/mpeg"
        }
      ])

    render_upload(upload, "Tavern Theme LOOP!!.MP3")

    form =
      form(view, "form", %{
        "entity" => %{
          "name" => "Tavern Theme",
          "category" => "ambient",
          "body" => "Loop for downtime scenes"
        }
      })

    render_change(form)
    render_submit(form)

    assert_redirect(view, "/entities/audio/tavern-theme")

    assert File.exists?(Path.join(campaign_dir, "audio/assets/tavern-theme-loop.mp3"))

    assert audio = Entities.get_entity!("audio", "tavern-theme")
    assert audio.category == "ambient"
    assert audio.asset_path == "audio/assets/tavern-theme-loop.mp3"
    assert audio.body_raw == "Loop for downtime scenes"
  end

  test "renders persisted audio values on edit", %{conn: conn, campaign_dir: campaign_dir} do
    file_path = Path.join(campaign_dir, "audio/tavern-theme.md")

    File.write!(file_path, """
    ---
    type: audio
    id: tavern-theme
    name: Tavern Theme
    category: ambient
    asset_path: audio/assets/tavern-theme-loop.mp3
    ---
    Loop for downtime scenes
    """)

    assert {:ok, _audio} =
             Entities.upsert_entity("audio", %{
               "id" => "tavern-theme",
               "name" => "Tavern Theme",
               "category" => "ambient",
               "asset_path" => "audio/assets/tavern-theme-loop.mp3",
               "tags" => [],
               "body_raw" => "Loop for downtime scenes",
               "body_html" => "<p>Loop for downtime scenes</p>",
               "file_path" => file_path
             })

    {:ok, _view, html} = live(conn, "/entities/audio/tavern-theme/edit")

    assert html =~ ~s(value="Tavern Theme")
    assert html =~ ~s(option value="ambient" selected)
    assert html =~ ~s(value="audio/assets/tavern-theme-loop.mp3")
  end
end
