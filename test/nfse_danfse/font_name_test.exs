defmodule NfseDanfse.FontNameTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.FontName

  @regular Application.app_dir(:nfse_danfse, "priv/fonts/LiberationSans-Regular.ttf")
  @bold Application.app_dir(:nfse_danfse, "priv/fonts/LiberationSans-Bold.ttf")

  describe "full_names/1" do
    test "reads the name of the font inside a file, of each font in a collection and none from other files" do
      dir = temporary_dir()
      assert FontName.full_names(@regular) == ["Liberation Sans"]

      collection_path = Path.join(dir, "liberation.ttc")
      File.write!(collection_path, collection([File.read!(@regular), File.read!(@bold)]))
      assert FontName.full_names(collection_path) == ["Liberation Sans", "Liberation Sans Bold"]

      not_a_font_path = Path.join(dir, "leia-me.ttf")
      File.write!(not_a_font_path, "Esta pasta guarda as fontes do DANFSe.")
      assert FontName.full_names(not_a_font_path) == []
      assert FontName.full_names(Path.join(dir, "ausente.ttf")) == []
    end
  end

  # Numa coleção, o cabeçalho lista onde cada fonte começa, e os deslocamentos das tabelas de cada
  # fonte passam a contar do começo da coleção.
  defp collection(fonts) do
    header_size = 12 + 4 * length(fonts)

    {font_offsets, _end} =
      Enum.map_reduce(fonts, header_size, fn font, offset ->
        {offset, offset + byte_size(font)}
      end)

    IO.iodata_to_binary([
      <<"ttcf", 1::16, 0::16, length(fonts)::32>>,
      Enum.map(font_offsets, &<<&1::32>>),
      Enum.zip_with(fonts, font_offsets, &shift_tables/2)
    ])
  end

  defp shift_tables(font, shift) do
    <<sfnt_version::binary-4, table_count::16, ranges::binary-6, rest::binary>> = font
    <<directory::binary-size(table_count * 16), tables::binary>> = rest

    shifted_directory =
      for <<tag::binary-4, checksum::32, offset::32, length::32 <- directory>>,
        into: <<>>,
        do: <<tag::binary, checksum::32, offset + shift::32, length::32>>

    <<sfnt_version::binary, table_count::16, ranges::binary, shifted_directory::binary,
      tables::binary>>
  end

  defp temporary_dir do
    dir = Path.join(System.tmp_dir!(), "font-name-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end
end
