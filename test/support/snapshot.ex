defmodule NfseDanfse.Snapshot do
  @moduledoc """
  Compara o DANFSe de uma nota com o hash guardado em `test/snapshots/<nome>.sha256`.

  O hash é o SHA-256 do SVG normalizado: um elemento por linha e as imagens embutidas (`data:`)
  trocadas por um marcador, para não depender do zlib que comprimiu o PNG do QR Code. Guardar só o
  hash evita repor megabytes de SVG no git a cada ajuste de leiaute.

  Na divergência grava `<nome>.actual.svg` e `<nome>.actual.png` ao lado do hash e falha.
  `UPDATE_SNAPSHOTS=1` regrava o hash e apaga os `.actual.*` que sobraram.
  """

  import ExUnit.Assertions

  alias NfseDanfse.Document

  @snapshots_dir Path.expand("../snapshots", __DIR__)

  @doc """
  Renderiza `xml` com as opções `opts`, exige uma página só e a compara com o snapshot `name`.
  """
  @spec assert_matches!(String.t(), binary(), keyword()) :: :ok
  def assert_matches!(name, xml, opts) do
    {:ok, {template, typst_options}} = Document.compile(xml, opts)
    {:ok, pages} = Typst.render_to_svg(template, [], typst_options)

    assert length(pages) == 1, "#{name} saiu com #{length(pages)} páginas"
    svg = pages |> hd() |> normalize()
    hash = :sha256 |> :crypto.hash(svg) |> Base.encode16(case: :lower)

    if System.get_env("UPDATE_SNAPSHOTS") == "1" do
      File.write!(snapshot_path(name, "sha256"), hash <> "\n")
      File.rm_rf!(snapshot_path(name, "actual.svg"))
      File.rm_rf!(snapshot_path(name, "actual.png"))
      :ok
    else
      compare(name, hash, svg, {template, typst_options})
    end
  end

  defp normalize(svg) do
    ~r/data:([^;,"]+)[^"]*/
    |> Regex.replace(svg, "data:\\1;omitido")
    |> String.replace("><", ">\n<")
    |> Kernel.<>("\n")
  end

  defp compare(name, hash, svg, {template, typst_options}) do
    if File.read(snapshot_path(name, "sha256")) == {:ok, hash <> "\n"} do
      :ok
    else
      {:ok, [png]} = Typst.render_to_png(template, [], [pixels_per_pt: 2.0] ++ typst_options)
      File.write!(snapshot_path(name, "actual.svg"), svg)
      File.write!(snapshot_path(name, "actual.png"), png)

      flunk("""
      O DANFSe de #{name} não confere com #{snapshot_path(name, "sha256")}.
      Abra #{snapshot_path(name, "actual.png")} para ver a página renderizada agora; o SVG
      normalizado está em #{snapshot_path(name, "actual.svg")}, para comparar com o de outro commit.
      Se a mudança for intencional, aceite com UPDATE_SNAPSHOTS=1 mix test.
      """)
    end
  end

  defp snapshot_path(name, extension), do: Path.join(@snapshots_dir, "#{name}.#{extension}")
end
