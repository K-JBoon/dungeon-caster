defmodule DungeonCaster.AudioTest do
  use ExUnit.Case
  alias DungeonCaster.Audio

  setup do
    # Create a temp audio directory structure
    dir = Application.get_env(:dungeon_caster, :campaign_dir)
    music_dir = Path.join(dir, "audio/music")
    sfx_combat = Path.join(dir, "audio/sfx/combat")
    sfx_env = Path.join(dir, "audio/sfx/environment")
    File.mkdir_p!(music_dir)
    File.mkdir_p!(sfx_combat)
    File.mkdir_p!(sfx_env)
    File.write!(Path.join(music_dir, "tavern.mp3"), "fake")
    File.write!(Path.join(sfx_combat, "sword-clash.mp3"), "fake")
    File.write!(Path.join(sfx_env, "rain.mp3"), "fake")
    :ok
  end

  test "list_music returns music tracks" do
    tracks = Audio.list_music()
    assert Enum.any?(tracks, &(&1.name == "tavern"))
    assert Enum.all?(tracks, &String.starts_with?(&1.path, "music/"))
  end

  test "list_sfx returns sfx grouped with section" do
    sfx = Audio.list_sfx()
    assert Enum.any?(sfx, &(&1.name == "sword-clash" and &1.section == "combat"))
    assert Enum.any?(sfx, &(&1.name == "rain" and &1.section == "environment"))
  end

  test "file_path returns absolute path" do
    path = Audio.file_path("music/tavern.mp3")
    assert String.ends_with?(path, "audio/music/tavern.mp3")
  end
end
