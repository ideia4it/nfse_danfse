# NfseDanfse

Biblioteca Elixir que gera o PDF do DANFSe v2.0 a partir do XML da NFS-e Nacional, pública no GitHub: nada de certificado real, senha ou documento de contribuinte em código, teste, fixture ou doc. Só renderização: nenhum schema de banco, contexto, worker ou rota. Quem liga a biblioteca a uma funcionalidade é o app que a consome.

## Comandos

```bash
mix deps.get
mix precommit      # compile --warnings-as-errors + format + credo --strict + test --cover (falha abaixo de 99% de cobertura)
```

## Regras

- Dependências de runtime: só `nfse`, `typst` e `eqrcode`
- Sem `Application`, sem processo e sem `Application.get_env`: tudo passa por opções
- Teste é jornada, um por fluxo, com nome em inglês no estilo BDD; testes de um módulo ficam no arquivo de teste dele
- Exemplos e fixtures usam a empresa fictícia "Studio Ana" e o CNPJ de teste `11222333000181`
- Nunca commitar PDF, XML, PNG ou SVG gerado de nota real
- O layout segue o PDF do governo; a NT 008 só decide o que o PDF do governo não mostra
- `@moduledoc`, `@doc`, comentários, README e guias em pt-BR; identificadores em inglês, exceto os campos da spec, que usam o nome do XSD em snake_case. Comentário só para o porquê. Nunca use travessão. Comentário que começa com "Todo" dispara o `TagTODO` do Credo: escreva "Cada", "A tabela inteira"
- Commits no estilo conventional, em pt-BR
- Push, PR e `mix hex.publish` só por ordem explícita
