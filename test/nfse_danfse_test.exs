defmodule NfseDanfseTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.Fixtures
  alias NfseDanfse.Glyphs
  alias NfseDanfse.Snapshot

  @nt_fonts_dir "/System/Library/Fonts/Supplemental"

  # O quadro do modelo da NT 008, em pt: margem de 3 mm, quatro colunas de 51 mm e 1,2 mm de folga
  # de cada lado do texto da célula.
  @millimeter 72 / 25.4
  @frame_left 3 * @millimeter
  @column_width 51 * @millimeter
  @cell_padding 1.2 * @millimeter
  # O SVG arredonda as posições em 9 casas.
  @tolerance 0.01

  describe "renders the DANFSe PDF in the government layout" do
    test "renders an ME/EPP note to a single-page PDF that matches its snapshot" do
      assert {:ok, <<"%PDF-", _::binary>>} = NfseDanfse.render(Fixtures.read!("me_epp"))
      Snapshot.assert_matches!("me_epp", Fixtures.read!("me_epp"), [])
    end

    test "marks cancelled and replaced notes with the watermark" do
      Snapshot.assert_matches!("me_epp_cancelled", Fixtures.read!("me_epp"),
        situation: :cancelled
      )

      Snapshot.assert_matches!("me_epp_replaced", Fixtures.read!("me_epp"), situation: :replaced)
    end

    test "renders the complete homologation note and the long texts on one page" do
      Snapshot.assert_matches!("complete", Fixtures.read!("complete"), [])
      Snapshot.assert_matches!("long_texts", Fixtures.read!("long_texts"), [])
    end

    test "keeps a note with every block and the longest texts on one page, cutting what does not fit" do
      longest_text =
        "Atendimento completo da equipe do Studio Ana no evento. "
        |> String.duplicate(40)
        |> String.slice(0, 2000)
        |> String.trim_trailing()

      every_block_and_longest_texts =
        Fixtures.read!("complete")
        |> replace!(~r{<xInfComp>.*</xInfComp>}s, "<xInfComp>#{longest_text}</xInfComp>")
        |> replace!("<regEspTrib>0</regEspTrib>", "<regEspTrib>6</regEspTrib>")

      Snapshot.assert_matches!(
        "every_block_and_longest_texts",
        replace!(
          every_block_and_longest_texts,
          ~r{<xDescServ>.*</xDescServ>}s,
          "<xDescServ>#{longest_text}</xDescServ>"
        ),
        []
      )

      one_service_per_line =
        1..80
        |> Enum.map_join("\n", &"Item #{&1}: corte, escova e manicure")
        |> String.slice(0, 2000)
        |> String.trim_trailing()

      Snapshot.assert_matches!(
        "every_block_and_one_service_per_line",
        replace!(
          every_block_and_longest_texts,
          ~r{<xDescServ>.*</xDescServ>}s,
          "<xDescServ>#{one_service_per_line}</xDescServ>"
        ),
        []
      )
    end

    test "wraps long links, an unbroken word and a long foreign NIF inside their frames" do
      long_link = "https://studioana.example/" <> Enum.map_join(1..40, "/", fn _ -> "agenda" end)
      unbroken_word = String.duplicate("a", 1300)
      foreign_nif = String.duplicate("1234567890", 4)

      xml =
        Fixtures.read!("complete")
        |> replace!(
          ~r{<xDescServ>.*</xDescServ>}s,
          "<xDescServ>Agende o retorno pelo link #{long_link} com o protocolo #{unbroken_word}</xDescServ>"
        )
        |> replace!(
          ~r{<xInfComp>.*</xInfComp>}s,
          "<xInfComp>Comprovante no link #{long_link} com o protocolo #{unbroken_word}</xInfComp>"
        )
        |> replace!("<CNPJ>11444777000161</CNPJ>", "<NIF>#{foreign_nif}</NIF>")

      assert {:ok, pdf} = NfseDanfse.render(xml)
      assert page_count(pdf) == 1

      glyphs = Glyphs.origins(xml)

      assert Enum.all?(glyphs, &inside_frame?/1)
      refute Enum.any?(lines(glyphs), &runs_into_next_cell?/1)
      Snapshot.assert_matches!("long_links", xml, [])
    end

    test "keeps the DANFSe on one page when the taker name has line breaks" do
      name_in_25_lines = String.duplicate("Ana\n", 25)
      xml = replace!(Fixtures.read!("complete"), "Clínica Exemplo Ltda", name_in_25_lines)

      assert {:ok, pdf} = NfseDanfse.render(xml)
      assert page_count(pdf) == 1
    end

    test "replaces absent blocks with one-line notices and drops the rows the note leaves empty" do
      without_taker_nor_issqn =
        Fixtures.read!("me_epp")
        |> replace!(~r{<toma>.*</toma>}s, "")
        |> replace!("<tribISSQN>1</tribISSQN>", "<tribISSQN>4</tribISSQN>")
        |> replace!("<cTribNac>010401</cTribNac>", "<cTribNac>990101</cTribNac>")
        |> replace!("<dCompet>2026-11-09</dCompet>", "<dCompet>2027-01-04</dCompet>")

      Snapshot.assert_matches!("without_taker_nor_issqn", without_taker_nor_issqn, [])

      recipient_is_taker_with_special_regime =
        Fixtures.read!("complete")
        |> replace!(~r{<indDest>1</indDest>\s*<dest>.*</dest>}s, "<indDest>0</indDest>")
        |> replace!("<regEspTrib>0</regEspTrib>", "<regEspTrib>6</regEspTrib>")

      Snapshot.assert_matches!(
        "recipient_is_taker_with_special_regime",
        recipient_is_taker_with_special_regime,
        []
      )
    end

    test "prints names with markup characters literally and without emoji" do
      xml = replace!(Fixtures.read!("me_epp"), "Ana Souza", "Ana #1 *Souza* &lt;%= x %&gt; 💇")

      assert {:ok, _pdf} = NfseDanfse.render(xml)
      Snapshot.assert_matches!("markup_in_name", xml, [])
    end

    @tag :nt_fonts
    test "renders with the fonts of the NT 008 when given a folder that has them under any file name" do
      assert {:ok, pdf} =
               NfseDanfse.render(Fixtures.read!("me_epp"),
                 fonts_dir: @nt_fonts_dir,
                 situation: :cancelled
               )

      assert pdf =~ "+ArialMT"
      assert pdf =~ "+Arial-BoldMT"
      assert pdf =~ "+MicrosoftSansSerif"
      refute pdf =~ "LiberationSans"

      windows_fonts_dir = temporary_dir("fontes-do-windows")

      for {macos_file, windows_file} <- [
            {"Arial.ttf", "arial.ttf"},
            {"Arial Bold.ttf", "arialbd.ttf"},
            {"Microsoft Sans Serif.ttf", "micross.ttf"}
          ] do
        File.ln_s!(
          Path.join(@nt_fonts_dir, macos_file),
          Path.join(windows_fonts_dir, windows_file)
        )
      end

      assert {:ok, windows_pdf} =
               NfseDanfse.render(Fixtures.read!("me_epp"), fonts_dir: windows_fonts_dir)

      assert windows_pdf =~ "+MicrosoftSansSerif"
      refute windows_pdf =~ "LiberationSans"
    end

    test "refuses bad input with an error that says what is wrong" do
      assert {:error, %NfseDanfse.Error{kind: :invalid_xml, cause: %Nfse.Error{}}} =
               NfseDanfse.render("<nada/>")

      assert {:error, %NfseDanfse.Error{kind: :invalid_option}} =
               NfseDanfse.render(Fixtures.read!("me_epp"), situation: :paid)

      assert {:error, %NfseDanfse.Error{kind: :invalid_option, message: unknown_message}} =
               NfseDanfse.render(Fixtures.read!("me_epp"), font_dir: "/tmp")

      assert unknown_message =~ "font_dir"

      assert {:error, %NfseDanfse.Error{kind: :invalid_option, message: unknown_keys_message}} =
               NfseDanfse.render(Fixtures.read!("me_epp"), font_dir: "/tmp", sitaution: :paid)

      assert unknown_keys_message =~ ":font_dir, :sitaution"

      empty_dir = temporary_dir("fontes-vazias")

      assert {:error, %NfseDanfse.Error{kind: :invalid_option, message: missing_message}} =
               NfseDanfse.render(Fixtures.read!("me_epp"), fonts_dir: empty_dir)

      assert missing_message =~ "fonte Arial,"

      assert {:error, %NfseDanfse.Error{kind: :invalid_option, message: absent_dir_message}} =
               NfseDanfse.render(Fixtures.read!("me_epp"),
                 fonts_dir: Path.join(empty_dir, "nao-existe")
               )

      assert absent_dir_message =~ "não existe"

      assert {:error, %NfseDanfse.Error{kind: :invalid_option, message: not_a_path_message}} =
               NfseDanfse.render(Fixtures.read!("me_epp"), fonts_dir: :pasta)

      assert not_a_path_message =~ ":pasta"

      other_fonts_dir = temporary_dir("outras-fontes")

      for name <- ["Arial.ttf", "Arial Bold.ttf", "Microsoft Sans Serif.ttf"] do
        File.cp!(
          Application.app_dir(:nfse_danfse, "priv/fonts/LiberationSans-Regular.ttf"),
          Path.join(other_fonts_dir, name)
        )
      end

      assert {:error, %NfseDanfse.Error{kind: :invalid_option, message: other_fonts_message}} =
               NfseDanfse.render(Fixtures.read!("me_epp"), fonts_dir: other_fonts_dir)

      assert other_fonts_message =~ "fonte Arial,"
    end
  end

  defp page_count(pdf), do: ~r{/Type\s*/Page\b} |> Regex.scan(pdf) |> length()

  defp inside_frame?({x, _y}),
    do:
      x > @frame_left + @cell_padding - @tolerance and
        x < @frame_left + 4 * @column_width - @cell_padding

  defp lines(glyphs) do
    glyphs
    |> Enum.group_by(fn {_x, y} -> Float.round(y, 2) end, fn {x, _y} -> x end)
    |> Map.values()
  end

  # Na linha em que uma célula começa, o vão de folga antes dela fica vazio; uma letra ali é texto
  # da célula anterior passando por cima desta.
  defp runs_into_next_cell?(line_xs) do
    Enum.any?(1..3, fn column ->
      cell_start = @frame_left + column * @column_width + @cell_padding
      gap_start = cell_start - 2 * @cell_padding

      Enum.any?(line_xs, &(abs(&1 - cell_start) < @tolerance)) and
        Enum.any?(line_xs, &(&1 > gap_start and &1 < cell_start - @tolerance))
    end)
  end

  defp replace!(xml, pattern, replacement) do
    replaced = String.replace(xml, pattern, replacement)
    refute replaced == xml, "#{inspect(pattern)} não está no XML"
    replaced
  end

  defp temporary_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end
end
