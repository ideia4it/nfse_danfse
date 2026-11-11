defmodule NfseDanfse.Document do
  @moduledoc false

  alias NfseDanfse.Error
  alias NfseDanfse.Fields
  alias NfseDanfse.FontName
  alias NfseDanfse.QrCode

  @template_path Path.expand("../../priv/danfse.typ", __DIR__)
  @logo_path Path.expand("../../priv/nfse_logo.png", __DIR__)
  @external_resource @template_path
  @external_resource @logo_path
  @template File.read!(@template_path)
  @logo File.read!(@logo_path)

  @situations [nil, :cancelled, :replaced]

  # Nome completo de cada fonte da NT 008 e os arquivos em que o macOS e o Windows a instalam.
  @nt_fonts [
    {"Arial", "Arial.ttf", "arial.ttf"},
    {"Arial Bold", "Arial Bold.ttf", "arialbd.ttf"},
    {"Microsoft Sans Serif", "Microsoft Sans Serif.ttf", "micross.ttf"}
  ]
  @nt_font_files for {_full_name, macos_file, windows_file} <- @nt_fonts,
                     file <- [macos_file, windows_file],
                     do: String.downcase(file)
  @font_extensions ~w(.ttf .ttc .otf)
  @nt_families %{
    fonts: %{label: "Arial", content: "Microsoft Sans Serif"},
    watermark_font: "Arial"
  }
  # Sem as fontes da NT 008, a Liberation Sans, com as medidas da Arial, ocupa os três papéis.
  @liberation_families %{
    fonts: %{label: "Liberation Sans", content: "Liberation Sans"},
    watermark_font: "Liberation Sans"
  }

  @doc """
  Template Typst do DANFSe da nota `xml` e as opções do Typst (`assets` e `extra_fonts`) que o
  renderizam, para que o PDF e o snapshot dos testes saiam da mesma composição.
  """
  @spec compile(binary(), keyword()) :: {:ok, {String.t(), keyword()}} | {:error, Error.t()}
  def compile(xml, opts) do
    with {:ok, opts} <- validate_options(opts),
         {:ok, nfse} <- decode(xml) do
      fields = Fields.build(nfse, opts[:situation])
      {:ok, {@template, typst_options(fields, opts[:fonts_dir])}}
    end
  end

  defp validate_options(opts) do
    with {:ok, opts} <- known_options(opts),
         :ok <- validate_situation(opts[:situation]),
         :ok <- validate_fonts_dir(opts[:fonts_dir]) do
      {:ok, opts}
    end
  end

  defp known_options(opts) do
    case Keyword.validate(opts, [:situation, :fonts_dir]) do
      {:ok, opts} -> {:ok, opts}
      {:error, unknown_keys} -> invalid_option(unknown_options_message(Enum.sort(unknown_keys)))
    end
  end

  defp unknown_options_message([unknown_key]),
    do: "A opção #{inspect(unknown_key)} não existe. Use :situation e :fonts_dir."

  defp unknown_options_message(unknown_keys),
    do:
      "As opções #{Enum.map_join(unknown_keys, ", ", &inspect/1)} não existem. " <>
        "Use :situation e :fonts_dir."

  defp validate_situation(situation) when situation in @situations, do: :ok

  defp validate_situation(situation),
    do:
      invalid_option(
        "A opção :situation aceita nil, :cancelled ou :replaced, e não #{inspect(situation)}."
      )

  defp validate_fonts_dir(nil), do: :ok

  defp validate_fonts_dir(fonts_dir) when not is_binary(fonts_dir),
    do:
      invalid_option(
        "A opção :fonts_dir aceita o caminho de uma pasta, e não #{inspect(fonts_dir)}."
      )

  defp validate_fonts_dir(fonts_dir) do
    case File.ls(fonts_dir) do
      {:ok, file_names} ->
        validate_nt_fonts(fonts_dir, file_names)

      {:error, _reason} ->
        invalid_option(
          "A pasta #{fonts_dir} da opção :fonts_dir não existe ou não pode ser lida."
        )
    end
  end

  # O Typst escolhe a fonte pelo nome gravado no arquivo, não pelo nome do arquivo: a busca é
  # pelo mesmo nome, para aceitar a Arial do Windows em arial.ttf e recusar outra fonte num
  # arquivo chamado Arial.ttf, que sairia como um PDF sem texto.
  defp validate_nt_fonts(fonts_dir, file_names) do
    fonts_dir
    |> missing_nt_fonts(file_names)
    |> Enum.find_value(:ok, fn {full_name, macos_file, windows_file} ->
      invalid_option(
        "A pasta #{fonts_dir} da opção :fonts_dir precisa ter a fonte #{full_name}, " <>
          "que fica no arquivo #{macos_file} no macOS e #{windows_file} no Windows."
      )
    end)
  end

  # Os arquivos com os nomes do macOS e do Windows são lidos primeiro, e a busca para quando acha
  # as três fontes: numa pasta com centenas de fontes, como a do sistema, a conferência de cada
  # render lê três arquivos em vez de todos.
  defp missing_nt_fonts(fonts_dir, file_names) do
    file_names
    |> Enum.filter(&(String.downcase(Path.extname(&1)) in @font_extensions))
    |> Enum.sort_by(&(String.downcase(&1) not in @nt_font_files))
    |> Enum.reduce_while(@nt_fonts, fn file_name, missing ->
      still_missing = fonts_not_in(missing, FontName.full_names(Path.join(fonts_dir, file_name)))
      {if(still_missing == [], do: :halt, else: :cont), still_missing}
    end)
  end

  defp fonts_not_in(nt_fonts, full_names) do
    Enum.reject(nt_fonts, fn {full_name, _macos_file, _windows_file} ->
      full_name in full_names
    end)
  end

  defp invalid_option(message), do: {:error, %Error{kind: :invalid_option, message: message}}

  defp decode(xml) do
    case Nfse.Sefin.decode_nfse(xml) do
      {:ok, nfse} ->
        {:ok, nfse}

      {:error, cause} ->
        {:error,
         %Error{kind: :invalid_xml, message: "O XML não é uma NFS-e legível.", cause: cause}}
    end
  end

  defp typst_options(fields, fonts_dir) do
    families = if fonts_dir, do: @nt_families, else: @liberation_families

    [
      assets: [
        {"fields.json", JSON.encode!(Map.merge(fields, families))},
        {"logo.png", @logo},
        {"qr.png", QrCode.png(fields.identification.access_key)}
      ],
      extra_fonts: [fonts_dir || Application.app_dir(:nfse_danfse, "priv/fonts")]
    ]
  end
end
