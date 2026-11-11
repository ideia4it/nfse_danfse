defmodule NfseDanfse.QrCode do
  @moduledoc false

  # O PDF do governo aponta para a consulta sem a barra antes do "?", embora a NT 008 escreva
  # ".../ConsultaPublica/?tpc=1&chave=". O leiaute segue o PDF do governo.
  @public_query_url "https://www.nfse.gov.br/ConsultaPublica?tpc=1&chave="
  @image_width 450
  @dark_pixel <<0, 0, 0>>
  @light_pixel <<255, 255, 255>>
  @png_signature <<137, "PNG", 13, 10, 26, 10>>
  @rgb_8_bits_without_alpha <<8, 2, 0, 0, 0>>
  @row_without_filter 0

  @doc """
  PNG do QR Code da consulta pública da NFS-e de chave `access_key`, com 450 pixels de lado.

  A imagem é RGB sem canal alfa, como a do PDF do governo: com alfa, o leitor de PDF compõe a
  máscara de transparência e os cinzas da borda dos módulos mudam.
  """
  @spec png(String.t()) :: binary()
  def png(access_key) do
    %EQRCode.Matrix{matrix: matrix} = EQRCode.encode(@public_query_url <> access_key, :m)
    rows = Tuple.to_list(matrix)
    pixels_per_module = round(@image_width / length(rows))
    side = length(rows) * pixels_per_module

    IO.iodata_to_binary([
      @png_signature,
      chunk("IHDR", <<side::32, side::32, @rgb_8_bits_without_alpha::binary>>),
      chunk("IDAT", :zlib.compress(Enum.map(rows, &pixel_rows(&1, pixels_per_module)))),
      chunk("IEND", "")
    ])
  end

  defp pixel_rows(modules, pixels_per_module) do
    pixels = for module <- Tuple.to_list(modules), do: module_pixels(module, pixels_per_module)
    List.duplicate([@row_without_filter, pixels], pixels_per_module)
  end

  defp module_pixels(1, pixels_per_module), do: :binary.copy(@dark_pixel, pixels_per_module)
  defp module_pixels(_light, pixels_per_module), do: :binary.copy(@light_pixel, pixels_per_module)

  defp chunk(type, body) do
    [<<byte_size(body)::32>>, type, body, <<:erlang.crc32(type <> body)::32>>]
  end
end
