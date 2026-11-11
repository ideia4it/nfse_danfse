defmodule NfseDanfse.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ideia4it/nfse_danfse"

  def project do
    [
      app: :nfse_danfse,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Gera o PDF do DANFSe v2.0 a partir do XML da NFS-e Nacional.",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      test_coverage: test_coverage()
    ]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:dev), do: ["lib", "dev"]
  defp elixirc_paths(:test), do: ["lib", "dev", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      # O leiaute foi medido contra o PDF do governo com o compilador do typst 0.4.5 e o QR Code com
      # a matriz do eqrcode 0.2.1; uma versão nova pode mover glifos ou trocar módulos do QR.
      {:nfse, "~> 0.1.0"},
      {:typst, "~> 0.4.5"},
      {:eqrcode, "~> 0.2.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "credo --strict",
        "test --cover"
      ]
    ]
  end

  # As tarefas mix de dev/ usam a rede e não fazem parte do pacote publicado. O Snapshot só regrava
  # ou falha quando o leiaute muda, caminhos que uma suíte verde nunca percorre.
  defp test_coverage do
    [
      ignore_modules: [
        Mix.Tasks.NfseDanfse.Gen.Places,
        Mix.Tasks.NfseDanfse.Compare,
        NfseDanfse.Snapshot
      ],
      summary: [threshold: 99]
    ]
  end

  defp package do
    [
      licenses: ["MIT", "OFL-1.1"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "guides/fontes.md", "CHANGELOG.md"],
      groups_for_extras: [Guias: ~r/^guides\//],
      # As tarefas mix de dev/ só existem no repositório e não vão no pacote.
      filter_modules: ~r/^Elixir\.NfseDanfse(\.|$)/
    ]
  end
end
