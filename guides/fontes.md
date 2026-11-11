# Fontes

A NT 008 manda imprimir os rótulos do DANFSe em Arial e o conteúdo em Microsoft Sans Serif. As duas são da Microsoft e a licença delas não permite redistribuí-las com a biblioteca. Por isso nenhuma das duas vem no pacote.

## O que vem no pacote

A biblioteca embute a Liberation Sans 2.1.5 (regular e negrito), sob a SIL Open Font License 1.1, cujo texto está em `priv/fonts/LICENSE`. Ela foi desenhada com as mesmas métricas da Arial: cada letra ocupa a mesma largura. Com ela, a posição de todo texto e a quebra de linha são idênticas às do PDF do governo. O que muda é o desenho das letras, que é parecido e não igual.

Sem nenhuma opção, é isso que você recebe:

```elixir
{:ok, pdf} = NfseDanfse.render(xml)
```

## Usando as fontes reais

Para o PDF sair pixel perfect, aponte `fonts_dir` para uma pasta com as três fontes:

```elixir
{:ok, pdf} = NfseDanfse.render(xml, fonts_dir: "fontes-da-nt")
```

A biblioteca acha cada fonte pelo nome gravado dentro dos arquivos `.ttf`, `.ttc` e `.otf` da própria pasta (as subpastas ficam de fora), e não pelo nome do arquivo. Servem os arquivos como o macOS e o Windows os instalam:

| Fonte | macOS | Windows |
|---|---|---|
| Arial | `Arial.ttf` | `arial.ttf` |
| Arial Bold | `Arial Bold.ttf` | `arialbd.ttf` |
| Microsoft Sans Serif | `Microsoft Sans Serif.ttf` | `micross.ttf` |

Se faltar uma das três fontes, ou se um arquivo com o nome certo tiver outra fonte dentro, `render/2` devolve `{:error, %NfseDanfse.Error{kind: :invalid_option}}` com o nome da fonte que falta. A biblioteca nunca cai para a Liberation em silêncio, para que ninguém ache que está gerando o PDF com as fontes reais sem estar.

Você é quem responde pela licença das fontes. Se o PDF vai para produção, a sua empresa precisa de licença para usar a Arial e a Microsoft Sans Serif no servidor.

## As fontes do sistema também entram

O compilador do Typst, que a biblioteca usa por um NIF, carrega as fontes instaladas no sistema antes das fontes que a biblioteca passa a ele. Na prática:

  * Uma Liberation Sans de outra versão instalada na máquina pode ser usada no lugar da embutida, e a forma das letras muda um pouco.
  * Com `fonts_dir`, uma Arial ou uma Microsoft Sans Serif instalada no sistema ganha dos arquivos da pasta: o NIF carrega as fontes do sistema primeiro, e o Typst fica com a primeira fonte que tem o nome pedido. Uma Arial de outra versão, como a 2.82 do pacote de fontes da Microsoft no Debian, pode sair no PDF no lugar da que está na pasta, e a validação de `fonts_dir` não muda isso. Sem `fonts_dir` isso não acontece: o template pede só a Liberation Sans e não usa fonte de reserva, então uma Arial do sistema nunca é usada.

Se o seu objetivo é um resultado repetível entre máquinas, rode a geração em um ambiente cujas fontes você controla, por exemplo uma imagem de contêiner sem fontes extras, e passe `fonts_dir`.
