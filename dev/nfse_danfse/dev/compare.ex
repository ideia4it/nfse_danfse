defmodule NfseDanfse.Dev.Compare do
  @moduledoc false

  @tolerance_in_points 0.1
  @watermark_min_height_in_points 20
  @pairing_radius_in_points 20
  @number "(-?\\d+(?:\\.\\d+)?(?:[eE][-+]?\\d+)?)"
  @word_pattern Regex.compile!(
                  ~s|<word xMin="#{@number}" yMin="#{@number}" xMax="#{@number}" yMax="#{@number}">([^<]*)</word>|
                )
  @entities [{"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""}, {"&apos;", "'"}, {"&amp;", "&"}]

  # A base da palavra (yMax) é a referência vertical: os dois geradores de PDF declaram ascendentes
  # diferentes para a mesma fonte, então yMin varia por constante enquanto os glifos ficam no mesmo lugar.
  def parse_words(bbox) do
    words =
      for [_match, x_min, y_min, _x_max, y_max, text] <- Regex.scan(@word_pattern, bbox) do
        %{
          text: unescape(text),
          x: parse_number(x_min),
          y: parse_number(y_max),
          height: parse_number(y_max) - parse_number(y_min)
        }
      end

    declared = bbox |> String.split("<word ") |> length() |> Kernel.-(1)

    if declared != length(words) do
      raise ArgumentError, "#{declared - length(words)} tag(s) <word> fora do formato esperado"
    end

    words
  end

  # A marca d'água é o único texto inclinado do DANFSe, e no texto inclinado o xMin do pdftotext
  # inclui o ascendente que ele tira de cada fonte, diferente entre os geradores. Cada pedaço dela
  # sai numa caixa de 30 pt ou mais de altura; o maior texto horizontal, o título de 9 pt, de 10 pt.
  def split_watermark(words) do
    Enum.split_with(words, &(&1.height < @watermark_min_height_in_points))
  end

  def match_words(reference, ours) do
    {positional, reference_left, ours_left} = pair_by_position(reference, ours)

    {reference_singles, reference_left, ours_left} =
      pair_concatenated(reference_left, ours_left)

    {ours_singles, ours_left, reference_left} = pair_concatenated(ours_left, reference_left)

    pairs =
      positional ++
        reference_singles ++
        Enum.map(ours_singles, fn {ours_word, reference_word} -> {reference_word, ours_word} end)

    %{
      shifted: pairs |> Enum.sort_by(fn {word, _} -> {word.y, word.x} end) |> shifted(),
      missing: reference_left,
      extra: ours_left
    }
  end

  def percentage_different(differing_pixels, {width, height}) do
    differing_pixels / (width * height) * 100
  end

  defp pair_by_position(reference, ours) do
    indexed_reference = Enum.with_index(reference)
    indexed_ours = Enum.with_index(ours)

    candidates =
      for {reference_word, i} <- indexed_reference,
          {our_word, j} <- indexed_ours,
          reference_word.text == our_word.text,
          distance = distance(reference_word, our_word),
          distance <= @pairing_radius_in_points,
          do: {distance, i, j}

    {pairs, used_reference, used_ours} =
      candidates
      |> Enum.sort()
      |> Enum.reduce({[], MapSet.new(), MapSet.new()}, &take_candidate/2)

    {
      Enum.map(pairs, fn {i, j} -> {Enum.at(reference, i), Enum.at(ours, j)} end),
      leftovers(indexed_reference, used_reference),
      leftovers(indexed_ours, used_ours)
    }
  end

  defp take_candidate({_distance, i, j}, {pairs, used_reference, used_ours} = state) do
    if MapSet.member?(used_reference, i) or MapSet.member?(used_ours, j) do
      state
    else
      {[{i, j} | pairs], MapSet.put(used_reference, i), MapSet.put(used_ours, j)}
    end
  end

  defp leftovers(indexed_words, used_indexes) do
    for {word, index} <- indexed_words, not MapSet.member?(used_indexes, index), do: word
  end

  defp distance(first, second), do: abs(first.x - second.x) + abs(first.y - second.y)

  defp pair_concatenated(singles, parts) do
    Enum.reduce(singles, {[], [], parts}, fn single, {pairs, singles_left, parts_left} ->
      case find_concatenation(single, parts_left) do
        {:ok, [first_part | _] = matched} ->
          {[{single, first_part} | pairs], singles_left, parts_left -- matched}

        :error ->
          {pairs, singles_left ++ [single], parts_left}
      end
    end)
    |> then(fn {pairs, singles_left, parts_left} ->
      {Enum.reverse(pairs), singles_left, parts_left}
    end)
  end

  defp find_concatenation(single, parts) do
    parts
    |> Enum.filter(&(abs(&1.y - single.y) <= @tolerance_in_points))
    |> Enum.sort_by(& &1.x)
    |> Enum.drop_while(&(abs(&1.x - single.x) > @tolerance_in_points))
    |> accumulate_until(single.text, [])
  end

  defp accumulate_until([], _target, _taken), do: :error

  defp accumulate_until([part | rest], target, taken) do
    taken = taken ++ [part]
    text = Enum.map_join(taken, & &1.text)

    cond do
      text == target and length(taken) > 1 -> {:ok, taken}
      String.starts_with?(target, text) -> accumulate_until(rest, target, taken)
      true -> :error
    end
  end

  defp shifted(pairs) do
    pairs
    |> Enum.map(fn {reference_word, our_word} ->
      {reference_word, our_word, our_word.x - reference_word.x, our_word.y - reference_word.y}
    end)
    |> Enum.filter(fn {_reference_word, _our_word, dx, dy} ->
      abs(dx) > @tolerance_in_points or abs(dy) > @tolerance_in_points
    end)
  end

  defp parse_number(text) do
    {number, ""} = Float.parse(text)
    number
  end

  defp unescape(text) do
    Enum.reduce(@entities, text, fn {entity, character}, acc ->
      String.replace(acc, entity, character)
    end)
  end
end
