defmodule NfseDanfse.FontName do
  @moduledoc false

  # Registro da tabela `name` na plataforma Windows, Unicode BMP, inglês dos EUA: é o que toda Arial
  # e Microsoft Sans Serif traz, nos arquivos do Windows e do macOS.
  @english_full_name {3, 1, 0x409, 4}

  @doc """
  Nomes completos das fontes do arquivo `path`, como `["Arial Bold"]`, lidos da tabela `name`: um
  por fonte numa coleção `.ttc` e nenhum quando o arquivo não é uma fonte legível.

  Lê só o cabeçalho e a tabela `name` de cada fonte, para que conferir uma pasta cheia de fontes
  não leia cada arquivo inteiro.
  """
  @spec full_names(Path.t()) :: [String.t()]
  def full_names(path) do
    case File.open(path, [:read, :binary], &read_full_names/1) do
      {:ok, full_names} -> full_names
      {:error, _reason} -> []
    end
  end

  defp read_full_names(file) do
    file
    |> font_offsets()
    |> Enum.flat_map(&full_name_at(file, &1))
  end

  # Numa coleção, cada fonte começa num deslocamento listado no cabeçalho, e os deslocamentos das
  # tabelas de cada uma contam do começo do arquivo, como numa fonte avulsa.
  defp font_offsets(file) do
    with {:ok, <<"ttcf", _version::32, font_count::32>>} <- :file.pread(file, 0, 12),
         {:ok, <<offsets::binary-size(font_count * 4)>>} <- :file.pread(file, 12, font_count * 4) do
      for <<offset::32 <- offsets>>, do: offset
    else
      _single_font -> [0]
    end
  end

  defp full_name_at(file, font_offset) do
    with {:ok, <<_version::32, table_count::16, _ranges::binary-6>>} <-
           :file.pread(file, font_offset, 12),
         {:ok, directory} <- :file.pread(file, font_offset + 12, table_count * 16),
         [{offset, length}] <- table_location(directory, "name"),
         {:ok, name_table} <- :file.pread(file, offset, length),
         <<_format::16, record_count::16, strings_offset::16, rest::binary>> <- name_table,
         <<records::binary-size(record_count * 12), _::binary>> <- rest,
         <<_::binary-size(strings_offset), strings::binary>> <- name_table do
      records
      |> english_full_names(strings)
      |> Enum.take(1)
    else
      _unreadable -> []
    end
  end

  defp table_location(directory, tag) do
    for <<entry_tag::binary-4, _checksum::32, offset::32, length::32 <- directory>>,
        entry_tag == tag,
        do: {offset, length}
  end

  defp english_full_names(records, strings) do
    for <<platform::16, encoding::16, language::16, name_id::16, length::16,
          offset::16 <- records>>,
        {platform, encoding, language, name_id} == @english_full_name,
        <<_::binary-size(offset), name::binary-size(length), _::binary>> <- [strings],
        full_name when is_binary(full_name) <-
          [:unicode.characters_to_binary(name, {:utf16, :big})],
        do: full_name
  end
end
