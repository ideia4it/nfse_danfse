defmodule NfseDanfse.Format do
  @moduledoc false

  @windows_1252_extras ~c"€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ"

  @doc """
  Máscara de CNPJ: `"11222333000181"` vira `"11.222.333/0001-81"`.
  """
  @spec cnpj(String.t()) :: String.t()
  def cnpj(<<a::binary-2, b::binary-3, c::binary-3, d::binary-4, e::binary-2>>),
    do: "#{a}.#{b}.#{c}/#{d}-#{e}"

  @doc """
  Máscara de CPF: `"52998224725"` vira `"529.982.247-25"`.
  """
  @spec cpf(String.t()) :: String.t()
  def cpf(<<a::binary-3, b::binary-3, c::binary-3, d::binary-2>>), do: "#{a}.#{b}.#{c}-#{d}"

  @doc """
  Máscara de CEP: `"40000000"` vira `"40.000-000"`.
  """
  @spec cep(String.t()) :: String.t()
  def cep(<<a::binary-2, b::binary-3, c::binary-3>>), do: "#{a}.#{b}-#{c}"

  @doc """
  Máscara do código IBGE do município: `"2927408"` vira `"29.27408"`.
  """
  @spec ibge_code(String.t()) :: String.t()
  def ibge_code(<<state::binary-2, municipality::binary>>), do: "#{state}.#{municipality}"

  @doc """
  Valor em reais com separador de milhar e duas casas: `"R$ 1.234.567,80"`. Valor ausente sai `"-"`.
  """
  @spec money(Decimal.t() | nil) :: String.t()
  def money(nil), do: "-"
  def money(amount), do: "R$ " <> brazilian_number(amount)

  @doc """
  Percentual com duas casas: `Decimal.new("5")` vira `"5,00%"`. Percentual ausente sai `"-"`.
  """
  @spec percent(Decimal.t() | nil) :: String.t()
  def percent(nil), do: "-"
  def percent(rate), do: brazilian_number(rate) <> "%"

  @doc "Data no formato `dd/mm/aaaa`."
  @spec date(Date.t()) :: String.t()
  def date(date), do: Calendar.strftime(date, "%d/%m/%Y")

  @doc """
  Data e hora no horário de Brasília, `dd/mm/aaaa hh:mm:ss`.

  Brasília é UTC-3 sem horário de verão desde 2019, então basta deslocar três horas.
  """
  @spec datetime(DateTime.t()) :: String.t()
  def datetime(instant) do
    instant
    |> DateTime.add(-3 * 3600)
    |> Calendar.strftime("%d/%m/%Y %H:%M:%S")
  end

  @doc """
  Corta o texto que passa de `limit` caracteres e acrescenta `"..."`, sem apagar o espaço do corte.
  """
  @spec truncate(String.t(), pos_integer()) :: String.t()
  def truncate(text, limit) do
    if String.length(text) > limit, do: String.slice(text, 0, limit) <> "...", else: text
  end

  @doc """
  Remove os caracteres que o PDF não codifica (tudo fora do Windows-1252), mantendo a quebra de linha.

  Antes do filtro, junta a letra e o acento que o XML traz decompostos ("a" seguido do til), que
  sairiam do filtro sem o acento.
  """
  @spec printable(String.t()) :: String.t()
  def printable(text) do
    text
    |> String.normalize(:nfc)
    |> String.to_charlist()
    |> Enum.filter(&windows_1252?/1)
    |> List.to_string()
  end

  @doc """
  Devolve `"-"` para valor ausente ou vazio.
  """
  @spec or_dash(String.t() | nil) :: String.t()
  def or_dash(nil), do: "-"
  def or_dash(""), do: "-"
  def or_dash(text), do: text

  @doc """
  Texto livre de um campo de uma linha como o DANFSe imprime: cada sequência de quebras de linha e
  tabulações, com os espaços em volta, vira um espaço (e some no começo e no fim); saem os
  caracteres que o PDF não codifica; e sai `"-"` quando ausente ou vazio.

  O leiaute reserva uma linha para esses campos, e só a descrição do serviço e as informações
  complementares encolhem para caber na página: um nome com quebras de linha levaria o fim do
  DANFSe para uma segunda página.
  """
  @spec text(String.t() | nil) :: String.t()
  def text(nil), do: "-"
  def text(value), do: value |> single_line() |> printable() |> or_dash()

  @doc """
  Como `text/1`, cortado em `limit` caracteres como em `truncate/2`.

  O corte vem depois da limpeza para que os caracteres removidos não contem no limite.
  """
  @spec text(String.t() | nil, pos_integer()) :: String.t()
  def text(value, limit), do: value |> text() |> truncate(limit)

  @doc """
  Texto livre que o DANFSe imprime em várias linhas, a descrição do serviço e as informações
  complementares: mantém as quebras de linha, troca a tabulação por espaço, tira os caracteres que
  o PDF não codifica e corta em `limit` caracteres como em `truncate/2`.
  """
  @spec multiline_text(String.t(), pos_integer()) :: String.t()
  def multiline_text(value, limit) do
    value
    |> String.replace(~r/\r\n?/, "\n")
    |> String.replace("\t", " ")
    |> printable()
    |> or_dash()
    |> truncate(limit)
  end

  defp single_line(text) do
    text
    |> String.split(~r/[ \t\r\n]*[\t\r\n][ \t\r\n]*/, trim: true)
    |> Enum.join(" ")
  end

  defp windows_1252?(codepoint) when codepoint in 0x20..0x7E, do: true
  defp windows_1252?(codepoint) when codepoint in 0xA0..0xFF, do: true
  defp windows_1252?(?\n), do: true
  defp windows_1252?(codepoint), do: codepoint in @windows_1252_extras

  defp brazilian_number(decimal) do
    [integer_part, fraction] =
      decimal
      |> Decimal.round(2)
      |> Decimal.to_string(:normal)
      |> String.split(".")

    group_thousands(integer_part) <> "," <> fraction
  end

  defp group_thousands(digits), do: Regex.replace(~r/\B(?=(\d{3})+(?!\d))/, digits, ".")
end
