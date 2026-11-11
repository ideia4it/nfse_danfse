defmodule Mix.Tasks.NfseDanfse.Compare do
  @shortdoc "Compara o nosso DANFSe com o PDF do governo para a mesma nota"

  @moduledoc """
  Renderiza o XML, compara as palavras (posição em pt) e os pixels (150 dpi) com o PDF de referência
  e imprime o relatório. Sai com status 1 se houver palavra deslocada, faltante ou sobrando.

  Com `--situation`, a marca d'água fica fora da comparação de palavras e só a de pixels a confere:
  o `pdftotext` mede o texto inclinado por um ascendente que muda de um gerador para o outro.

  Exige `pdftotext` e `pdftoppm` (Poppler) e `magick` (ImageMagick 7).

      mix nfse_danfse.compare --xml nota.xml --reference governo.pdf \\
        [--fonts-dir DIR] [--situation cancelled|replaced] [--out DIR]
  """

  use Mix.Task

  alias NfseDanfse.Dev.Compare

  @required_tools ["pdftotext", "pdftoppm", "magick"]
  @switches [
    xml: :string,
    reference: :string,
    fonts_dir: :string,
    situation: :string,
    out: :string
  ]

  @impl Mix.Task
  def run(args) do
    {options, _rest} = OptionParser.parse!(args, strict: @switches)
    ensure_tools_installed!()
    Mix.Task.run("app.start")

    xml_path = required_option!(options, :xml)
    reference_pdf = required_option!(options, :reference)
    out_dir = Keyword.get_lazy(options, :out, &new_tmp_dir/0)
    File.mkdir_p!(out_dir)

    our_pdf = Path.join(out_dir, "ours.pdf")
    File.write!(our_pdf, render!(xml_path, options))

    words_report = compare_words(reference_pdf, our_pdf, options[:situation])
    print_words_report(words_report)
    print_pixels_report(reference_pdf, our_pdf, out_dir)

    if Enum.any?(Map.values(words_report), &(&1 != [])), do: exit({:shutdown, 1})
  end

  defp required_option!(options, name) do
    Keyword.get_lazy(options, name, fn ->
      Mix.raise("Falta --#{name}. Uso: mix nfse_danfse.compare --xml PATH --reference PATH")
    end)
  end

  defp ensure_tools_installed! do
    case Enum.reject(@required_tools, &System.find_executable/1) do
      [] -> :ok
      missing -> Mix.raise("Ferramentas ausentes no PATH: #{Enum.join(missing, ", ")}")
    end
  end

  defp new_tmp_dir do
    Path.join(System.tmp_dir!(), "nfse_danfse_compare_#{System.unique_integer([:positive])}")
  end

  defp render!(xml_path, options) do
    render_options =
      [fonts_dir: options[:fonts_dir], situation: parse_situation!(options[:situation])]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    {:ok, pdf} = NfseDanfse.render(File.read!(xml_path), render_options)
    pdf
  end

  defp parse_situation!(nil), do: nil
  defp parse_situation!("cancelled"), do: :cancelled
  defp parse_situation!("replaced"), do: :replaced

  defp parse_situation!(other) do
    Mix.raise("--situation deve ser cancelled ou replaced, recebido: #{inspect(other)}")
  end

  defp compare_words(reference_pdf, our_pdf, situation) do
    {reference, reference_watermark} =
      set_aside_watermark(extract_words(reference_pdf), situation)

    {ours, our_watermark} = set_aside_watermark(extract_words(our_pdf), situation)

    if situation do
      Mix.shell().info(
        "Marca d'água fora da comparação de palavras, conferida só pelos pixels: " <>
          "#{describe_pieces(reference_watermark)} na referência, " <>
          "#{describe_pieces(our_watermark)} no nosso"
      )
    end

    Compare.match_words(reference, ours)
  end

  defp set_aside_watermark(words, nil), do: {words, []}
  defp set_aside_watermark(words, _situation), do: Compare.split_watermark(words)

  defp describe_pieces(pieces) do
    "#{length(pieces)} pedaços (#{Enum.map_join(pieces, " ", & &1.text)})"
  end

  defp extract_words(pdf_path) do
    bbox = run!("pdftotext", ["-bbox", pdf_path, "-"])
    Compare.parse_words(bbox)
  end

  defp print_words_report(%{shifted: shifted, missing: missing, extra: extra}) do
    Mix.shell().info(
      "Palavras: #{length(shifted)} deslocadas, #{length(missing)} faltantes, #{length(extra)} sobrando"
    )

    for {reference, _ours, dx, dy} <- shifted do
      Mix.shell().info(
        "  deslocada #{inspect(reference.text)} dx=#{round_pt(dx)} dy=#{round_pt(dy)}"
      )
    end

    for word <- missing,
        do: Mix.shell().info("  faltante #{inspect(word.text)} na base y=#{round_pt(word.y)}")

    for word <- extra,
        do: Mix.shell().info("  sobrando #{inspect(word.text)} na base y=#{round_pt(word.y)}")
  end

  defp round_pt(points), do: Float.round(points, 2)

  defp print_pixels_report(reference_pdf, our_pdf, out_dir) do
    reference_png = rasterize(reference_pdf, Path.join(out_dir, "reference"))
    our_png = rasterize(our_pdf, Path.join(out_dir, "ours"))
    diff_png = Path.join(out_dir, "diff.png")

    {differing_pixels, size} = count_differing_pixels(reference_png, our_png, diff_png)
    percentage = Compare.percentage_different(differing_pixels, size)

    Mix.shell().info("Pixels: #{Float.round(percentage, 3)}% diferentes")
    Mix.shell().info("Diferença em #{diff_png}")
  end

  defp rasterize(pdf_path, output_prefix) do
    {_output, 0} =
      System.cmd("pdftoppm", ["-r", "150", "-png", "-singlefile", pdf_path, output_prefix])

    output_prefix <> ".png"
  end

  # O `magick compare` sai com 1 quando as imagens diferem e escreve a contagem no stderr.
  # Qualquer outro status (2 para tamanhos diferentes, por exemplo) é erro.
  defp count_differing_pixels(reference_png, our_png, diff_png) do
    output =
      run!("magick", ["compare", "-metric", "AE", reference_png, our_png, diff_png], [0, 1])

    {count, _rest} = output |> String.split() |> hd() |> Float.parse()
    {round(count), image_size(reference_png)}
  end

  defp image_size(png_path) do
    output = run!("magick", ["identify", "-format", "%w %h", png_path])
    [width, height] = output |> String.split() |> Enum.map(&String.to_integer/1)
    {width, height}
  end

  defp run!(command, arguments, accepted_statuses \\ [0]) do
    {output, status} = System.cmd(command, arguments, stderr_to_stdout: true)

    if status in accepted_statuses do
      output
    else
      Mix.raise("#{command} terminou com status #{status}: #{String.trim(output)}")
    end
  end
end
