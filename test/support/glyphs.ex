defmodule NfseDanfse.Glyphs do
  @moduledoc """
  Onde cada letra cai na página do DANFSe, lido do SVG que o Typst compõe.

  O hash do snapshot só diz que a página mudou; estas posições deixam o teste dizer onde o texto
  ficou, por exemplo que nenhuma letra passou da borda do quadro.
  """

  alias NfseDanfse.Document

  @identity {1.0, 0.0, 0.0, 1.0, 0.0, 0.0}

  @doc """
  A origem `{x, y}`, em pt a partir do canto superior esquerdo, de cada glifo da página da nota
  `xml` renderizada com as opções `opts`.
  """
  @spec origins(binary(), keyword()) :: [{float(), float()}]
  def origins(xml, opts \\ []) do
    {:ok, {template, typst_options}} = Document.compile(xml, opts)
    {:ok, [svg]} = Typst.render_to_svg(template, [], typst_options)

    {[@identity], []}
    |> walk(Regex.scan(~r{<(/?)(g|use)\b([^>]*)>}, svg, capture: :all_but_first))
    |> Enum.reverse()
  end

  defp walk({_transforms, origins}, []), do: origins

  defp walk({[parent | _] = transforms, origins}, [["", "g", attributes] | tags]) do
    if String.ends_with?(attributes, "/"),
      do: walk({transforms, origins}, tags),
      else: walk({[compose(parent, transform(attributes)) | transforms], origins}, tags)
  end

  defp walk({[_closed | transforms], origins}, [["/", "g", _] | tags]),
    do: walk({transforms, origins}, tags)

  defp walk({[current | _] = transforms, origins}, [["", "use", attributes] | tags]) do
    origin = apply_transform(current, {attribute(attributes, "x"), attribute(attributes, "y")})
    walk({transforms, [origin | origins]}, tags)
  end

  defp transform(attributes) do
    case Regex.run(~r/transform="(\w+)\(([^)]*)\)"/, attributes, capture: :all_but_first) do
      nil -> @identity
      ["translate", values] -> with [x, y] <- numbers(values), do: {1.0, 0.0, 0.0, 1.0, x, y}
      ["scale", values] -> with [x, y] <- numbers(values), do: {x, 0.0, 0.0, y, 0.0, 0.0}
      ["matrix", values] -> values |> numbers() |> List.to_tuple()
    end
  end

  defp compose({a, b, c, d, e, f}, {a2, b2, c2, d2, e2, f2}) do
    {a * a2 + c * b2, b * a2 + d * b2, a * c2 + c * d2, b * c2 + d * d2, a * e2 + c * f2 + e,
     b * e2 + d * f2 + f}
  end

  defp apply_transform({a, b, c, d, e, f}, {x, y}), do: {a * x + c * y + e, b * x + d * y + f}

  defp attribute(attributes, name) do
    [value] = Regex.run(~r/\s#{name}="([^"]*)"/, attributes, capture: :all_but_first)
    parse_number(value)
  end

  defp numbers(values),
    do: values |> String.split([" ", ","], trim: true) |> Enum.map(&parse_number/1)

  defp parse_number(number) do
    {value, ""} = Float.parse(number)
    value
  end
end
