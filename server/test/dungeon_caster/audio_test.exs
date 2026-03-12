defmodule DungeonCaster.AudioTest do
  use ExUnit.Case, async: false

  alias DungeonCaster.Audio

  setup do
    campaign_dir = Application.fetch_env!(:dungeon_caster, :campaign_dir)
    asset_root = Path.join(campaign_dir, "audio")

    File.rm_rf!(asset_root)
    File.mkdir_p!(Path.join(asset_root, "music"))
    File.mkdir_p!(Path.join(asset_root, "sfx"))

    mp3_path = Path.join(asset_root, "music/tavern.mp3")
    ogg_path = Path.join(asset_root, "sfx/rain.ogg")

    File.write!(mp3_path, "fake mp3")
    File.write!(ogg_path, "fake ogg")

    on_exit(fn -> File.rm_rf!(asset_root) end)

    {:ok, campaign_dir: campaign_dir, mp3_path: mp3_path, ogg_path: ogg_path}
  end

  test "managed helpers resolve campaign audio assets", %{campaign_dir: campaign_dir} do
    assert Audio.upload_accept() == ".mp3,.ogg,.wav,.m4a,.aac,.flac"
    assert Audio.asset_root() == Path.join(campaign_dir, "audio")
    assert Audio.managed_asset_path("music/tavern.mp3") == Path.join(campaign_dir, "audio/music/tavern.mp3")
    assert Audio.asset_url("music/tavern.mp3") == "/audio/music/tavern.mp3"
  end

  test "audio_file_available?/1 accepts supported files within the managed root", %{
    mp3_path: mp3_path,
    ogg_path: ogg_path
  } do
    assert Audio.audio_file_available?("music/tavern.mp3")
    assert Audio.audio_file_available?("sfx/rain.ogg")
    refute Audio.audio_file_available?("music/missing.mp3")
    refute Audio.audio_file_available?("../secrets.mp3")
    refute Audio.audio_file_available?("music/tavern.txt")

    File.rm!(mp3_path)
    File.rm!(ogg_path)
  end

  test "audio_file_available?/1 rejects symlink escapes under the managed root", %{
    campaign_dir: campaign_dir
  } do
    outside_dir = Path.join(campaign_dir, "outside-audio")
    outside_file = Path.join(outside_dir, "secret.mp3")
    symlink_path = Path.join(Audio.asset_root(), "music/secret.mp3")

    File.mkdir_p!(outside_dir)
    File.write!(outside_file, "outside")
    File.ln_s!(outside_file, symlink_path)

    on_exit(fn -> File.rm_rf!(outside_dir) end)

    refute Audio.audio_file_available?("music/secret.mp3")
  end

  test "audio_file_available?/1 rejects chained symlink escapes under the managed root", %{
    campaign_dir: campaign_dir
  } do
    outside_dir = Path.join(campaign_dir, "outside-audio")
    outside_file = Path.join(outside_dir, "secret.mp3")
    first_hop = Path.join(Audio.asset_root(), "music/first-hop.mp3")
    second_hop = Path.join(Audio.asset_root(), "music/second-hop.mp3")

    File.mkdir_p!(outside_dir)
    File.write!(outside_file, "outside")
    File.ln_s!(outside_file, second_hop)
    File.ln_s!(second_hop, first_hop)

    on_exit(fn -> File.rm_rf!(outside_dir) end)

    refute Audio.audio_file_available?("music/first-hop.mp3")
  end

  test "audio_file_available?/1 accepts relative symlinks that stay within the managed root" do
    source_path = Path.join(Audio.asset_root(), "music/shared.mp3")
    symlink_path = Path.join(Audio.asset_root(), "sfx/shared.mp3")

    File.write!(source_path, "shared")
    File.ln_s!("../music/shared.mp3", symlink_path)

    assert Audio.audio_file_available?("sfx/shared.mp3")
  end

  test "resolve_audio_file/1 returns the resolved safe path for a valid managed symlink" do
    source_path = Path.join(Audio.asset_root(), "music/shared.mp3")
    symlink_path = Path.join(Audio.asset_root(), "sfx/shared.mp3")

    File.write!(source_path, "shared")
    File.ln_s!("../music/shared.mp3", symlink_path)

    assert {:ok, ^source_path} = Audio.resolve_audio_file("sfx/shared.mp3")
  end

  test "resolve_audio_file/1 rejects parent-directory symlink escapes under the managed root", %{
    campaign_dir: campaign_dir
  } do
    outside_dir = Path.join(campaign_dir, "outside-music")
    outside_file = Path.join(outside_dir, "secret.mp3")

    File.rm_rf!(Path.join(Audio.asset_root(), "music"))
    File.mkdir_p!(outside_dir)
    File.write!(outside_file, "outside")
    File.ln_s!(outside_dir, Path.join(Audio.asset_root(), "music"))

    on_exit(fn -> File.rm_rf!(outside_dir) end)

    assert Audio.resolve_audio_file("music/secret.mp3") == :error
    refute Audio.audio_file_available?("music/secret.mp3")
  end

  test "list_music/0 does not surface tracks through parent-directory symlink escapes", %{
    campaign_dir: campaign_dir
  } do
    outside_dir = Path.join(campaign_dir, "outside-music")
    outside_file = Path.join(outside_dir, "secret.mp3")

    File.rm_rf!(Path.join(Audio.asset_root(), "music"))
    File.mkdir_p!(outside_dir)
    File.write!(outside_file, "outside")
    File.ln_s!(outside_dir, Path.join(Audio.asset_root(), "music"))

    on_exit(fn -> File.rm_rf!(outside_dir) end)

    refute Enum.any?(Audio.list_music(), &(&1.path == "music/secret.mp3"))
  end
end

defmodule DungeonCasterWeb.AudioControllerTest do
  use DungeonCasterWeb.ConnCase, async: false

  setup do
    campaign_dir = Application.fetch_env!(:dungeon_caster, :campaign_dir)
    asset_root = Path.join(campaign_dir, "audio")

    File.rm_rf!(asset_root)
    File.mkdir_p!(Path.join(asset_root, "music"))
    File.mkdir_p!(Path.join(asset_root, "sfx"))

    File.write!(Path.join(asset_root, "music/tavern.mp3"), "fake mp3")
    File.write!(Path.join(asset_root, "sfx/rain.ogg"), "fake ogg")

    on_exit(fn -> File.rm_rf!(asset_root) end)
    :ok
  end

  test "streams managed audio with content type inferred from extension", %{conn: conn} do
    conn = get(conn, ~p"/audio/sfx/rain.ogg")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["audio/ogg; charset=utf-8"]
  end

  test "returns not found when the managed audio file is unavailable", %{conn: conn} do
    conn = get(conn, ~p"/audio/music/missing.mp3")

    assert conn.status == 404
    assert conn.resp_body == "not found"
  end
end
