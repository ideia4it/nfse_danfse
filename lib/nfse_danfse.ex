defmodule NfseDanfse do
  @moduledoc """
  Gera o PDF do DANFSe v2.0 a partir do XML da NFS-e Nacional, no leiaute do DANFSe que o Emissor
  Nacional imprime.

      {:ok, pdf} = NfseDanfse.render(xml)
      {:ok, pdf} = NfseDanfse.render(xml, situation: :cancelled)
  """

  alias NfseDanfse.Document
  alias NfseDanfse.Error

  @doc """
  Renderiza o PDF do DANFSe da NFS-e `xml`.

  ## Opções

    * `:situation` - `:cancelled` ou `:replaced` imprimem a marca d'água "CANCELADA" ou
      "SUBSTITUÍDA". A NFS-e não carrega essa informação, então quem chama diz. Padrão `nil`.
    * `:fonts_dir` - pasta com a Arial, a Arial Bold e a Microsoft Sans Serif, as fontes que a
      NT 008 exige e que não podem ser redistribuídas com a biblioteca. Cada uma é achada pelo
      nome gravado dentro dos arquivos `.ttf`, `.ttc` e `.otf` da pasta, então servem os arquivos
      do macOS (`Arial.ttf`) e os do Windows (`arial.ttf`). Sem ela, o DANFSe sai na Liberation
      Sans, que tem as medidas da Arial.

  Devolve `{:error, %NfseDanfse.Error{}}` com `kind` `:invalid_xml` quando o XML não é uma NFS-e
  legível, `:invalid_option` para opção desconhecida ou inválida e `:render` quando a composição
  do PDF falha.
  """
  @spec render(binary(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def render(xml, opts \\ []) do
    with {:ok, {template, typst_options}} <- Document.compile(xml, opts) do
      case Typst.render_to_pdf(template, [], typst_options) do
        {:ok, pdf} -> {:ok, pdf}
        {:error, message} -> {:error, %Error{kind: :render, message: message}}
      end
    end
  end
end
