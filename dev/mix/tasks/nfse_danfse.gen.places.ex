defmodule Mix.Tasks.NfseDanfse.Gen.Places do
  @shortdoc "Baixa os municípios do IBGE e grava priv/municipios.csv"

  @moduledoc """
  Baixa a lista de municípios da API de localidades do IBGE e grava `priv/municipios.csv`
  com o cabeçalho `codigo;nome;uf`, ordenado pelo código.

  A UF vem de `regiao-imediata`, `regiao-intermediaria`, `UF`, `sigla`, porque a `microrregiao`
  vem nula em alguns municípios.

      mix nfse_danfse.gen.places
  """

  use Mix.Task

  @url ~c"https://servicodados.ibge.gov.br/api/v1/localidades/municipios"
  @output_path "priv/municipios.csv"

  @impl Mix.Task
  def run(_args) do
    {:ok, _apps} = Application.ensure_all_started([:inets, :ssl])

    rows =
      download()
      |> JSON.decode!()
      |> Enum.map(&to_row/1)
      |> Enum.sort()

    lines = ["codigo;nome;uf" | Enum.map(rows, &Enum.join(&1, ";"))]
    File.write!(@output_path, Enum.join(lines, "\n") <> "\n")

    Mix.shell().info("#{length(lines)} linhas gravadas em #{@output_path}")
  end

  defp download do
    http_options = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
      ]
    ]

    {:ok, {{_version, 200, _reason}, _headers, body}} =
      :httpc.request(:get, {@url, []}, http_options, body_format: :binary)

    body
  end

  defp to_row(%{"id" => id, "nome" => name} = municipality) do
    uf = get_in(municipality, ["regiao-imediata", "regiao-intermediaria", "UF", "sigla"])
    [Integer.to_string(id), name, uf]
  end
end
