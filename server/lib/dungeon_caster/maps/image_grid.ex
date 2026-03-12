defmodule DungeonCaster.Maps.ImageGrid do
  @moduledoc false

  @default_grid {96, 54}
  @cell_size_px 20

  def grid_dims(nil), do: @default_grid
  def grid_dims(""), do: @default_grid

  def grid_dims(path) do
    with {:ok, bin} <- File.read(path),
         {:ok, {width, height}} <- image_size(bin) do
      {ceil(width / @cell_size_px), ceil(height / @cell_size_px)}
    else
      _ -> @default_grid
    end
  end

  defp image_size(<<0x89, "PNG\r\n\x1A\n", _len::32, "IHDR", width::32-big, height::32-big, _rest::binary>>) do
    {:ok, {width, height}}
  end

  defp image_size(<<"GIF87a", width::16-little, height::16-little, _rest::binary>>), do: {:ok, {width, height}}
  defp image_size(<<"GIF89a", width::16-little, height::16-little, _rest::binary>>), do: {:ok, {width, height}}

  defp image_size(<<"RIFF", _size::32-little, "WEBP", rest::binary>>) do
    webp_size(rest)
  end

  defp image_size(<<0xFF, 0xD8, rest::binary>>) do
    jpeg_size(rest)
  end

  defp image_size(_), do: :error

  defp webp_size(<<"VP8X", _chunk_size::32-little, _flags, _reserved::binary-size(3),
                   width_minus_one::24-little, height_minus_one::24-little, _rest::binary>>) do
    {:ok, {width_minus_one + 1, height_minus_one + 1}}
  end

  defp webp_size(<<"VP8 ", _chunk_size::32-little, _frame_tag::binary-size(3), 0x9D, 0x01, 0x2A,
                  width_and_flags::16-little, height_and_flags::16-little, _rest::binary>>) do
    {:ok, {Bitwise.band(width_and_flags, 0x3FFF), Bitwise.band(height_and_flags, 0x3FFF)}}
  end

  defp webp_size(<<"VP8L", _chunk_size::32-little, 0x2F, bits::32-little, _rest::binary>>) do
    width = Bitwise.band(bits, 0x3FFF) + 1
    height = Bitwise.band(Bitwise.bsr(bits, 14), 0x3FFF) + 1
    {:ok, {width, height}}
  end

  defp webp_size(_), do: :error

  defp jpeg_size(binary), do: jpeg_size(binary, nil)

  defp jpeg_size(<<>>, _), do: :error
  defp jpeg_size(<<0xFF, marker, rest::binary>>, _)
       when marker in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF] do
    case rest do
      <<segment_len::16-big, _precision, height::16-big, width::16-big, _tail::binary>>
      when segment_len >= 7 ->
        {:ok, {width, height}}

      _ ->
        :error
    end
  end

  defp jpeg_size(<<0xFF, marker, rest::binary>>, _) when marker in [0xD8, 0xD9] do
    jpeg_size(rest, nil)
  end

  defp jpeg_size(<<0xFF, 0xDA, _rest::binary>>, _), do: :error

  defp jpeg_size(<<0xFF, _marker, segment_len::16-big, rest::binary>>, _) when segment_len >= 2 do
    skip = segment_len - 2

    case rest do
      <<_segment::binary-size(skip), tail::binary>> -> jpeg_size(tail, nil)
      _ -> :error
    end
  end

  defp jpeg_size(<<_byte, rest::binary>>, _), do: jpeg_size(rest, nil)
end
