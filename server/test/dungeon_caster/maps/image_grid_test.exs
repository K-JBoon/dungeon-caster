defmodule DungeonCaster.Maps.ImageGridTest do
  use ExUnit.Case, async: true

  alias DungeonCaster.Maps.ImageGrid

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "image_grid_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  test "reads grid dimensions from png assets", %{tmp_dir: tmp_dir} do
    path = write_binary!(tmp_dir, "map.png", png(40, 20))

    assert ImageGrid.grid_dims(path) == {2, 1}
  end

  test "reads grid dimensions from gif assets", %{tmp_dir: tmp_dir} do
    path = write_binary!(tmp_dir, "map.gif", gif(20, 40))

    assert ImageGrid.grid_dims(path) == {1, 2}
  end

  test "reads grid dimensions from jpeg assets", %{tmp_dir: tmp_dir} do
    path = write_binary!(tmp_dir, "map.jpg", jpeg(40, 20))

    assert ImageGrid.grid_dims(path) == {2, 1}
  end

  test "reads grid dimensions from webp assets", %{tmp_dir: tmp_dir} do
    path = write_binary!(tmp_dir, "map.webp", webp_vp8x(40, 20))

    assert ImageGrid.grid_dims(path) == {2, 1}
  end

  test "falls back for unsupported or invalid image files", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "broken.bin")
    File.write!(path, "not an image")

    assert ImageGrid.grid_dims(path) == {96, 54}
  end

  defp write_binary!(dir, name, binary) do
    path = Path.join(dir, name)
    File.write!(path, binary)
    path
  end

  defp png(width, height) do
    <<0x89, "PNG\r\n\x1A\n", 13::32-big, "IHDR", width::32-big, height::32-big, 8, 6, 0, 0, 0>>
  end

  defp gif(width, height) do
    <<"GIF89a", width::16-little, height::16-little, 0, 0, 0>>
  end

  defp jpeg(width, height) do
    <<0xFF, 0xD8, 0xFF, 0xE0, 0, 16, "JFIF\0", 1, 1, 0, 0, 1, 0, 1, 0, 0, 0xFF, 0xC0, 0, 17, 8,
      height::16-big, width::16-big, 3, 1, 17, 0, 2, 17, 1, 3, 17, 1, 0xFF, 0xD9>>
  end

  defp webp_vp8x(width, height) do
    width_minus_one = width - 1
    height_minus_one = height - 1

    chunk =
      <<"VP8X", 10::32-little, 0, 0, 0, 0, width_minus_one::24-little,
        height_minus_one::24-little>>

    <<"RIFF", byte_size(chunk)::32-little, "WEBP", chunk::binary>>
  end
end
