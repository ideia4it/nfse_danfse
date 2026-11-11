defmodule NfseDanfse.QrCodeTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.QrCode

  @access_key "21113002211222333000181000000000000126110000000001"
  @rgb_without_alpha 2
  @module_pixels 10

  describe "png/1" do
    test "draws the portal query link the government prints as an opaque image of 450 pixels" do
      png = QrCode.png(@access_key)

      assert {450, 450, @rgb_without_alpha, pixel_rows} = decode(png)

      %EQRCode.Matrix{matrix: matrix} =
        EQRCode.encode("https://www.nfse.gov.br/ConsultaPublica?tpc=1&chave=" <> @access_key, :m)

      expected_dark_modules =
        for row <- Tuple.to_list(matrix), do: for(module <- Tuple.to_list(row), do: module == 1)

      assert dark_modules(pixel_rows) == expected_dark_modules
    end
  end

  defp decode(<<137, "PNG", 13, 10, 26, 10, chunks::binary>>) do
    {header, data} = read_chunks(chunks, nil, [])
    <<width::32, height::32, 8, color_type, 0, 0, 0>> = header
    rows = for <<0, row::binary-size(width * 3) <- :zlib.uncompress(data)>>, do: row
    {width, height, color_type, rows}
  end

  defp read_chunks(
         <<length::32, type::binary-4, body::binary-size(length), _crc::32, rest::binary>>,
         header,
         data
       ) do
    case type do
      "IHDR" -> read_chunks(rest, body, data)
      "IDAT" -> read_chunks(rest, header, [data, body])
      "IEND" -> {header, IO.iodata_to_binary(data)}
    end
  end

  defp dark_modules(pixel_rows) do
    for row <- Enum.take_every(pixel_rows, @module_pixels) do
      for <<red, _rest_of_module::binary-size(@module_pixels * 3 - 1) <- row>>, do: red == 0
    end
  end
end
