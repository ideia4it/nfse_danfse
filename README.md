# NfseDanfse

Gera o PDF do DANFSe v2.0 a partir do XML da NFS-e Nacional, no mesmo leiaute que o portal nacional imprime.

Desde 15/07/2026 a API do ADN que devolvia o PDF está suspensa (NT 008 v1.01, item 1: a API "será sobrestada (suspensa) na data de 15 de julho de 2026"), e cada emissor passa a gerar o próprio DANFSe. Esta biblioteca lê o XML com a [`nfse`](https://github.com/ideia4it/nfse), monta os campos e compõe o PDF em uma página, sem depender de serviço externo.

Só depende de `nfse`, `typst` e `eqrcode`.

## Instalação

```elixir
def deps do
  [
    {:nfse_danfse, "~> 0.1.0"}
  ]
end
```

Requer Elixir 1.18 ou mais novo. O pacote `typst` traz o compilador como NIF pré-compilado, então não é preciso instalar Rust.

## Exemplo

O DANFSe de uma nota do "Studio Ana", como voltou da Sefin ou do ADN:

```elixir
xml = File.read!("nota-studio-ana.xml")

{:ok, pdf} = NfseDanfse.render(xml)
File.write!("danfse.pdf", pdf)
```

A NFS-e não diz que foi cancelada, porque o cancelamento é um evento à parte. Quem chama informa a situação, e o PDF sai com a marca d'água:

```elixir
{:ok, pdf} = NfseDanfse.render(xml, situation: :cancelled)
```

Toda falha volta como `{:error, %NfseDanfse.Error{}}`, com `kind` `:invalid_xml` (o XML não é uma NFS-e legível), `:invalid_option` (opção desconhecida ou inválida) ou `:render` (a composição do PDF falhou).

## Opções

| Opção | Valores | Efeito |
|---|---|---|
| `:situation` | `:cancelled`, `:replaced` | Imprime a marca d'água "CANCELADA" ou "SUBSTITUÍDA", em corpo 72 pt como o portal. Sem a opção, não há marca. |
| `:fonts_dir` | caminho de uma pasta | Usa as fontes reais da NT: Arial, Arial Bold e Microsoft Sans Serif. Cada uma é achada pelo nome gravado dentro dos arquivos da pasta, então servem os arquivos do macOS (`Arial.ttf`) e os do Windows (`arial.ttf`). Sem a opção, usa a Liberation Sans embutida. Uma pasta sem alguma das três fontes devolve `{:error, %NfseDanfse.Error{kind: :invalid_option}}`. Veja o guia [Fontes](guides/fontes.md). |

## O que a biblioteca garante

  * Segue a NT 008 v1.01 (SE/CGNFS-e, 30/06/2026). Onde o PDF do governo e a NT divergem, a biblioteca segue o PDF do governo, que é o que o contribuinte vê no portal. Por exemplo: o campo "Valor Líquido da NFS-e + IBS/CBS" de uma nota do Simples Nacional sai "R$ 0,00", como no portal; o QR Code codifica `https://www.nfse.gov.br/ConsultaPublica?tpc=1&chave=<chave>`, sem a barra antes do `?` que o texto da NT traz; e a marca d'água tem 72 pt.
  * Em comparação com dois PDFs do portal, e com as fontes reais (Arial e Microsoft Sans Serif), a biblioteca difere em 0,008% dos pixels a 150 dpi, e toda palavra fica a até 0,014 pt da posição do governo.
  * A página é sempre uma só (NT §2.2). A descrição do serviço e as informações complementares que passam do quadro são cortadas com "..." no fim.
  * Os dados do cliente entram no PDF como dados, nunca como marcação: um nome com `#`, `*` ou `<` aparece literal. Letras fora da Windows-1252 (como "ł", "ő" e emoji) são removidas, e um nome com elas sai sem elas.

## Desempenho

Medido num notebook com Apple Silicon: cerca de 170 ms por nota simples e 230 ms por uma nota completa. O primeiro render leva cerca de 0,5 s, porque o Typst varre as fontes do sistema. O NIF do Typst guarda um só conjunto de fontes por vez, então alternar entre `fonts_dir` e as fontes embutidas no mesmo app faz a varredura de novo, cerca de 300 ms a cada troca.

## Por que não há logo da empresa

Não existe opção para colocar a logo do emitente, e isso é de propósito. Três itens da NT 008 impedem a logo:

  * O item 2.1 só permite imprimir o que consta do XML da NFS-e, e o XML não traz logo.
  * O item 2.2.4 torna obrigatório o modelo do Anexo I, em que o canto esquerdo do cabeçalho é a logo da NFS-e.
  * O item 2.3 lista as únicas supressões e modificações permitidas, e a logo da empresa não está entre elas.

Um DANFSe com a logo da empresa deixaria de ser o documento que a norma descreve. Por isso a biblioteca não aceita a opção, e um pedido nesse sentido não será atendido. A NT está em [gov.br/nfse](https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/rtc/nt-008-se-cgnfse-danfse-20260505.pdf). Esse arquivo é a versão 1.0; a 1.01 (30/06/2026) mudou só a data de suspensão da API de geração do DANFSe, como diz o histórico de versões da própria NT.

## Para quem contribui

A tarefa mix `nfse_danfse.compare` compara o PDF gerado com o PDF do governo para a mesma nota, por palavras (posição em pt) e por pixels (150 dpi). Ela existe só em desenvolvimento e exige o Poppler (`pdftotext`, `pdftoppm`) e o ImageMagick 7 (`magick`):

```bash
mix nfse_danfse.compare --xml nota.xml --reference governo.pdf --fonts-dir ~/fontes-da-nt
```

O XML e o PDF do portal usados na comparação ficam fora do repositório. Notas reais nunca entram nele: nem XML, nem PDF, nem snapshot. Os testes usam só o Studio Ana, com o CNPJ de teste `11222333000181` e a tomadora fictícia Ana Souza.

## Guias

  * [Fontes](guides/fontes.md)

## Licença

MIT. A Liberation Sans embutida segue a SIL Open Font License 1.1 (veja `priv/fonts/LICENSE`).
