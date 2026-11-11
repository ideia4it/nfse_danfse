defmodule NfseDanfse.Descriptions do
  @moduledoc false

  alias NfseDanfse.Format

  # A tabela é fixa e fica aqui de propósito: o texto do DANFSe é do governo e não deve mudar
  # junto com a biblioteca `nfse`. Onde o governo não fixou a redação, vale o `xs:documentation`
  # do XSD 1.01 da NFS-e.
  @descriptions %{
    tp_emit: %{"1" => "Prestador", "2" => "Tomador", "3" => "Intermediário"},
    c_stat: %{
      "100" => "NFS-e Gerada",
      "101" => "NFS-e de Substituição Gerada",
      "102" => "NFS-e de Decisão Judicial ou Administrativa",
      "103" => "NFS-e Avulsa",
      "107" => "NFS-e MEI"
    },
    fin_nfse: %{"0" => "NFS-e regular"},
    op_simp_nac: %{
      "1" => "Não Optante",
      "2" => "Optante - Microempreendedor Individual (MEI)",
      "3" => "Optante - Microempresa ou Empresa de Pequeno Porte (ME/EPP)"
    },
    reg_ap_trib_sn: %{
      "1" => "Regime de apuração dos tributos federais e municipal pelo Simples Nacional",
      "2" =>
        "Regime de apuração dos tributos federais pelo SN e ISSQN por fora do SN conforme respectiva legislação municipal do tributo",
      "3" =>
        "Regime de apuração dos tributos federais e municipal por fora do SN conforme respectivas legislações federal e municipal de cada tributo"
    },
    reg_esp_trib: %{
      "0" => nil,
      "1" => "Ato Cooperado (Cooperativa)",
      "2" => "Estimativa",
      "3" => "Microempresa Municipal",
      "4" => "Notário ou Registrador",
      "5" => "Profissional Autônomo",
      "6" => "Sociedade de Profissionais",
      "9" => "Outros"
    },
    trib_issqn: %{
      "1" => "Operação Tributável",
      "2" => "Imunidade",
      "3" => "Exportação de Serviço",
      "4" => "Não Incidência"
    },
    tp_ret_issqn: %{
      "1" => "Não Retido",
      "2" => "Retido pelo Tomador",
      "3" => "Retido pelo Intermediario"
    },
    tp_imunidade: %{
      "0" => "Imunidade (tipo não informado na nota de origem)",
      "1" => "Patrimônio, renda ou serviços, uns dos outros (CF88, Art 150, VI, a)",
      "2" => "Templos de qualquer culto (CF88, Art 150, VI, b)",
      "3" =>
        "Patrimônio, renda ou serviços dos partidos políticos, inclusive suas fundações, das entidades sindicais dos trabalhadores, das instituições de educação e de assistência social, sem fins lucrativos, atendidos os requisitos da lei (CF88, Art 150, VI, c)",
      "4" =>
        "Livros, jornais, periódicos e o papel destinado a sua impressão (CF88, Art 150, VI, d)",
      "5" =>
        "Fonogramas e videofonogramas musicais produzidos no Brasil contendo obras musicais ou literomusicais de autores brasileiros e/ou obras em geral interpretadas por artistas brasileiros bem como os suportes materiais ou arquivos digitais que os contenham, salvo na etapa de replicação industrial de mídias ópticas de leitura a laser. (CF88, Art 150, VI, e)"
    },
    tp_susp: %{
      "1" => "Exigibilidade Suspensa por Decisão Judicial",
      "2" => "Exigibilidade Suspensa por Processo Administrativo"
    },
    # O xs:documentation do tpBM cita os campos do valor ('ppBM', 'vInfoBM', 'aliqDifBM'), que
    # sairiam literais no DANFSe.
    tp_bm: %{
      "1" => "Isenção",
      "2" => "Redução da BC em percentual",
      "3" => "Redução da BC em valor",
      "4" => "Alíquota Diferenciada"
    },
    tp_ret_pis_cofins: %{
      "0" => "PIS/COFINS/CSLL Não Retidos",
      "1" => "PIS/COFINS Retidos",
      "2" => "PIS/COFINS Não Retidos",
      "3" => "PIS/COFINS/CSLL Retidos",
      "4" => "PIS/COFINS Retidos, CSLL Não Retido",
      "5" => "PIS Retido, COFINS/CSLL Não Retido",
      "6" => "COFINS Retido, PIS/CSLL Não Retido",
      "7" => "PIS Não Retido, COFINS/CSLL Retidos",
      "8" => "PIS/COFINS Não Retidos, CSLL Retido",
      "9" => "COFINS Não Retido, PIS/CSLL Retidos"
    }
  }

  @doc """
  Devolve o texto do DANFSe para o `code` do `field`.

  Código desconhecido devolve o próprio código, e `nil` devolve `nil`. O código `"0"` de
  `:reg_esp_trib` ("Nenhum") devolve `nil`, porque o governo suprime a linha.

      iex> NfseDanfse.Descriptions.describe(:tp_emit, "1")
      "Prestador"
  """
  @spec describe(atom(), String.t() | nil) :: String.t() | nil
  def describe(_field, nil), do: nil

  def describe(field, code) do
    @descriptions
    |> Map.get(field, %{})
    |> Map.get(code, code)
  end

  @doc """
  A descrição de `describe/2` como o campo do DANFSe a imprime: `"-"` quando não há descrição.
  """
  @spec text(atom(), String.t() | nil) :: String.t()
  def text(field, code), do: field |> describe(code) |> Format.text()

  @doc """
  Como `text/2`, cortada em `limit` caracteres como em `NfseDanfse.Format.text/2`.
  """
  @spec text(atom(), String.t() | nil, pos_integer()) :: String.t()
  def text(field, code, limit), do: field |> describe(code) |> Format.text(limit)
end
