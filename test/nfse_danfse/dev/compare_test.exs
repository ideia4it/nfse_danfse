defmodule NfseDanfse.Dev.CompareTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.Dev.Compare

  describe "match_words/2" do
    test "pairs words by text and reports only the ones that moved more than 0.1 pt" do
      reference = [
        %{text: "NÚMERO", x: 10.0, y: 64.9},
        %{text: "73", x: 10.0, y: 72.7},
        %{text: "-", x: 300.0, y: 72.7}
      ]

      ours = [
        %{text: "NÚMERO", x: 10.05, y: 64.9},
        %{text: "73", x: 10.3, y: 72.7},
        %{text: "+", x: 300.0, y: 72.7}
      ]

      assert %{
               shifted: [{%{text: "73"}, %{text: "73"}, dx, +0.0}],
               missing: [%{text: "-"}],
               extra: [%{text: "+"}]
             } = Compare.match_words(reference, ours)

      assert_in_delta dx, 0.3, 0.0001
    end
  end

  describe "match_words/2 across producers" do
    test "pairs words emitted in a different order by nearest position" do
      reference = [%{text: "A", x: 10.0, y: 20.0}, %{text: "A", x: 200.0, y: 20.0}]
      ours = [%{text: "A", x: 200.05, y: 20.0}, %{text: "A", x: 10.0, y: 20.0}]

      assert %{shifted: [], missing: [], extra: []} = Compare.match_words(reference, ours)
    end

    test "reports a word with no equal text within 20 pt as missing and extra" do
      reference = [%{text: "A", x: 10.0, y: 20.0}]
      ours = [%{text: "A", x: 10.0, y: 60.0}]

      assert %{shifted: [], missing: [%{text: "A"}], extra: [%{text: "A"}]} =
               Compare.match_words(reference, ours)
    end

    test "matches a word against the consecutive words on its line that spell it, both ways" do
      joined = %{text: "-/-", x: 100.0, y: 50.0}

      parts = [
        %{text: "-", x: 100.0, y: 50.0},
        %{text: "/", x: 103.0, y: 50.0},
        %{text: "-", x: 106.0, y: 50.0}
      ]

      assert %{shifted: [], missing: [], extra: []} = Compare.match_words([joined], parts)
      assert %{shifted: [], missing: [], extra: []} = Compare.match_words(parts, [joined])

      other_line = Enum.map(parts, &%{&1 | y: 70.0})

      assert %{missing: [^joined], extra: ^other_line} = Compare.match_words([joined], other_line)
    end
  end

  describe "parse_words/1" do
    test "reads the words of a pdftotext bbox document and unescapes entities" do
      bbox = """
      <doc>
        <page width="595.000000" height="842.000000">
          <word xMin="10.500000" yMin="1.0" xMax="30.0" yMax="20.250000">A&amp;B</word>
        </page>
      </doc>
      """

      assert [%{text: "A&B", x: 10.5, y: 20.25, height: 19.25}] = Compare.parse_words(bbox)
    end
  end

  describe "split_watermark/1" do
    test "sets aside the tall diagonal pieces of the watermark and keeps a body word with the same text" do
      caption_word = %{text: "A", x: 445.6, y: 98.7, height: 6.8}
      title_word = %{text: "DANFSe", x: 269.6, y: 22.7, height: 10.1}

      watermark_pieces = [
        %{text: "C", x: 94.0, y: 593.9, height: 36.8},
        %{text: "AN", x: 130.8, y: 557.1, height: 70.7},
        %{text: "A", x: 371.1, y: 316.8, height: 33.9}
      ]

      assert {[^caption_word, ^title_word], ^watermark_pieces} =
               Compare.split_watermark([caption_word, title_word | watermark_pieces])
    end
  end

  describe "parse_words/1 robustness" do
    test "reads the bottom edge, negative coordinates and exponents" do
      bbox = ~s(<word xMin="-1.5" yMin="2" xMax="3" yMax="1.0e1">x</word>)

      assert [%{text: "x", x: -1.5, y: 10.0}] = Compare.parse_words(bbox)
    end

    test "refuses a word tag it cannot read" do
      assert_raise ArgumentError, fn -> Compare.parse_words(~s(<word xMin="a">x</word>)) end
    end
  end

  describe "percentage_different/2" do
    test "divides the differing pixels by the page area" do
      assert_in_delta Compare.percentage_different(50, {10, 10}), 50.0, 0.0001
    end
  end
end
