// DANFSe v2.0 na geometria do PDF que o Emissor Nacional gera com o MigraDoc. O template só
// posiciona os textos prontos de fields.json; as regras de cada campo ficam em NfseDanfse.Fields.

#let data = json(read("fields.json", encoding: none))

// Medidas verticais da Arial e da Microsoft Sans Serif em em. O MigraDoc põe o lineGap acima do
// texto e soma 1,5 mm abaixo de cada linha de campos. As posições saem destas medidas mesmo quando
// o texto usa a Liberation Sans, para que o leiaute não dependa da fonte.
#let arial = (gap: 67 / 2048, ascent: 1854 / 2048, descent: 434 / 2048)
#let sans-serif = (gap: 0, ascent: 1888 / 2048, descent: 430 / 2048)

#let baseline-offset(font, size) = (font.gap + font.ascent) * size
#let descent(font, size) = font.descent * size
#let line-pitch(font, size) = baseline-offset(font, size) + descent(font, size)

#let page-left = 3mm
#let page-top = 2mm
#let column = 51mm
#let cell-padding = 1.2mm
#let row-padding = 1.5mm
#let cell-gray = rgb(242, 242, 242)

// O canhoto termina a 9 mm do pé da A4 de 297 mm em que o MigraDoc compõe a página, com borda de
// 1 pt acima e abaixo de uma linha de campos.
#let stub-height = line-pitch(arial, 6pt) + line-pitch(sans-serif, 7pt) + row-padding + 2pt
#let stub-top = 297mm - 9mm - stub-height

// O PDFsharp trunca em milésimos de em a largura de cada glifo no /Widths, e o leitor de PDF avança
// os glifos de uma palavra por ela; só o começo da palavra sai da largura exata. O 0,0001 evita que
// uma largura inteira, como 500, caia para 499 pelo ponto flutuante.
#let truncated-advance(cluster) = {
  let thousandths-of-em = measure(cluster).width / text.size * 1000
  calc.floor(thousandths-of-em + 0.0001) / 1000 * text.size
}

#let pdfsharp-fragment(fragment) = context box(width: measure(fragment).width, {
  let x = 0pt
  for cluster in fragment.clusters() {
    place(dx: x, cluster)
    x += truncated-advance(cluster)
  }
})

// O MigraDoc escreve um fragmento por palavra e corta a palavra depois de cada hífen. O fragmento é
// uma caixa que não quebra; o mais largo que a linha, como um link longo, quebra depois das barras,
// e o pedaço entre barras ainda mais largo que a linha vira uma caixa por letra para não sair do
// quadro.
#let pdfsharp-text(body, line-width: none) = for token in body.matches(
  regex("[^ \n-]*-|[^ \n-]+|[ \n]"),
) {
  if token.text in (" ", "\n") {
    token.text
  } else if line-width != none and measure(token.text).width > line-width {
    for piece in token.text.matches(regex("[^/]*/+|[^/]+")) {
      if measure(piece.text).width > line-width {
        for cluster in piece.text.clusters() { pdfsharp-fragment(cluster) }
      } else {
        pdfsharp-fragment(piece.text)
      }
    }
  } else {
    pdfsharp-fragment(token.text)
  }
}

#let label-text(body, size: 6pt, fill: black) = text(
  font: data.fonts.label,
  weight: "bold",
  size: size,
  fill: fill,
  pdfsharp-text(body),
)

#let content-text(body, size: 7pt) = {
  set par(leading: line-pitch(sans-serif, size))
  text(
    font: data.fonts.content,
    size: size,
    layout(region => pdfsharp-text(body, line-width: region.width)),
  )
}

// Posição absoluta na página; o corpo começa nas margens esquerda e superior.
#let at(x, y, body) = place(top + left, dx: x - page-left, dy: y - page-top, body)

#let field(name, value, label-size: 6pt) = block(
  inset: (
    x: cell-padding,
    top: baseline-offset(arial, label-size),
    bottom: descent(sans-serif, 7pt) + row-padding,
  ),
  stack(
    spacing: descent(arial, label-size) + baseline-offset(sans-serif, 7pt),
    label-text(name, size: label-size),
    content-text(value),
  ),
)

#let titled(name) = grid.cell(
  fill: cell-gray,
  block(inset: (x: cell-padding, top: baseline-offset(arial, 7pt)), label-text(name, size: 7pt)),
)

#let span(count, body) = grid.cell(colspan: count, body)

#let row(..cells) = grid(columns: (column,) * 4, ..cells)

#let optional-row(values, cells) = if values == none { () } else { cells(values) }

// O governo traça a divisória da direita para a esquerda, e o leitor de PDF suaviza as pontas da
// linha conforme o sentido do traço.
#let divider = block(
  height: 0.5pt,
  place(dy: 0.25pt, line(start: (100%, 0pt), end: (0%, 0pt), stroke: 0.5pt)),
)

#let notice(message) = block(
  width: 100%,
  inset: (top: baseline-offset(sans-serif, 7pt), bottom: descent(sans-serif, 7pt)),
  align(center, content-text(message)),
)

#let page-border = place(top + left, dx: 5pt, dy: 5pt, rect(width: 585pt, height: 832pt, stroke: 1pt))

// O PDF do governo centraliza a palavra no meio da página, a 45 graus, com a linha de base
// 24,4424 pt abaixo do centro e preto com 40/255 de opacidade.
#let watermark(word) = place(
  top + left,
  dx: 297.5pt,
  dy: 421pt,
  rotate(-45deg, origin: top + left, box(place(
    top + center,
    dy: 24.4424pt,
    text(font: data.watermark_font, size: 72pt, fill: rgb(0, 0, 0, 40), pdfsharp-text(word)),
  ))),
)

#let header = {
  let title-line(body, fill: black) = block(
    inset: (top: baseline-offset(arial, 9pt), bottom: descent(arial, 9pt)),
    label-text(body, size: 9pt, fill: fill),
  )
  let environment-line(body, size) = block(
    inset: (top: baseline-offset(sans-serif, size), bottom: descent(sans-serif, size)),
    content-text(body, size: size),
  )
  let titles = (title-line("DANFSe v2.0"), title-line("Documento Auxiliar da NFS-e"))
  if data.header.without_legal_validity {
    titles.push(title-line("NFS-e SEM VALIDADE JURÍDICA", fill: rgb(255, 0, 0)))
  }
  let environment = (
    environment-line(data.header.generating_environment, 6pt),
    environment-line(data.header.environment, 6pt),
  )
  if data.header.municipality != none {
    environment.insert(0, environment-line(data.header.municipality, 8pt))
  }

  grid(
    columns: (column, 2 * column, column),
    rows: 12mm,
    fill: cell-gray,
    inset: (x: cell-padding),
    align: (left + top, center + horizon, left + horizon),
    place(dy: 10.3229pt - page-top, image("logo.png", width: 115.6536pt)),
    stack(..titles),
    stack(..environment),
  )
}

#let qr-code = {
  at(491.9882pt, 44.7642pt, image("qr.png", width: 45pt))
  let caption = (
    "A autenticidade desta NFS-e pode ser verificada",
    "pela leitura deste código QR ou pela consulta da",
    "chave de acesso no portal nacional da NFS-e",
  )
  for (index, caption-line) in caption.enumerate() {
    at(
      page-left + 3 * column + cell-padding,
      97.4145pt + index * line-pitch(sans-serif, 6pt),
      content-text(caption-line, size: 6pt),
    )
  }
}

#let identification = {
  let id = data.identification
  let id-field(name, value) = field(name, value, label-size: 7pt)
  v(row-padding)
  row(
    span(3, id-field("CHAVE DE ACESSO DA NFS-e", id.access_key)), [],
    id-field("NÚMERO DA NFS-e", id.nfse_number),
    id-field("COMPETÊNCIA DA NFS-e", id.competence),
    id-field("DATA E HORA DA EMISSÃO DA NFS-e", id.nfse_issued_at), [],
    id-field("NÚMERO DA DPS", id.dps_number),
    id-field("SÉRIE DA DPS", id.dps_series),
    id-field("DATA E HORA DA EMISSÃO DA DPS", id.dps_issued_at), [],
    grid.cell(fill: cell-gray, id-field("EMITENTE DA NFS-e", id.issuer)),
    id-field("SITUAÇÃO DA NFS-e", id.status),
    id-field("FINALIDADE", id.purpose), [],
  )
}

// O destinatário não tem inscrição municipal, e o DANFSe deixa a célula vazia.
#let party-rows(title, party) = (
  titled(title),
  field("CNPJ / CPF / NIF", party.document),
  if "municipal_registration" in party {
    field("Indicador Municipal (Inscrição)", party.municipal_registration)
  } else { [] },
  field("Telefone", party.phone),
  span(2, field("Nome / Nome Empresarial", party.name)),
  field("Município / Sigla UF", party.municipality),
  field("Código IBGE / CEP", party.ibge_cep),
  span(2, field("Endereço", party.address)),
  span(2, field("E-mail", party.email)),
)

#let party-section(title, party, missing) = if party == none {
  notice(missing)
} else {
  row(..party-rows(title, party))
}

#let provider = {
  let provider = data.provider
  row(
    ..party-rows("PRESTADOR / FORNECEDOR", provider),
    field("Simples Nacional na Data de Competência", provider.simples_nacional),
    span(3, field("Regime de Apuração Tributária pelo SN", provider.simples_regime)),
  )
}

#let recipient = if data.recipient_is_taker {
  notice("O DESTINATÁRIO É O PRÓPRIO TOMADOR/ADQUIRENTE DA OPERAÇÃO")
} else {
  party-section(
    "DESTINATÁRIO DA OPERAÇÃO",
    data.recipient,
    "DESTINATÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e",
  )
}

#let service(description) = {
  let service = data.service
  row(
    titled("SERVIÇO PRESTADO"),
    field("Código de Tributação Nacional/Municipal", service.tax_code),
    field("Código da NBS", service.nbs_code),
    field("Local da Prestação / Sigla UF / País", service.location),
    span(4, block(
      inset: (
        x: cell-padding,
        top: baseline-offset(sans-serif, 7pt),
        bottom: descent(sans-serif, 7pt) + row-padding,
      ),
      content-text(service.tax_code_description),
    )),
    span(4, field("Descrição do Serviço", description)),
  )
}

#let municipal-tax = if data.municipal_tax == none {
  notice("TRIBUTAÇÃO MUNICIPAL (ISSQN) - OPERAÇÃO NÃO SUJEITA AO ISSQN")
} else {
  let tax = data.municipal_tax
  row(
    titled("TRIBUTAÇÃO MUNICIPAL (ISSQN)"),
    field("Tipo de Tributação do ISSQN", tax.taxation_type),
    span(2, field("Município / Sigla UF / País de Incidência do ISSQN", tax.incidence)),
    ..optional-row(tax.special_regime_row, regime => (
      field("Regime Especial de Tributação do ISSQN", regime.special_regime),
      field("Tipo de Imunidade do ISSQN", regime.immunity),
      field("Suspensão da Exigibilidade do ISSQN", regime.suspension),
      field("Número Processo Suspensão", regime.suspension_process),
    )),
    ..optional-row(tax.benefit_row, benefit => (
      field("Benefício Municipal", benefit.benefit),
      field("Cálculo do BM", benefit.benefit_calculation),
      field("Total Deduções/Reduções", benefit.deductions),
      field("Desconto Incondicionado", benefit.unconditional_discount),
    )),
    field("BC ISSQN", tax.base),
    field("Alíquota Aplicada", tax.rate),
    field("Retenção do ISSQN", tax.retention),
    field("ISSQN Apurado", tax.issqn),
  )
}

#let federal-tax = {
  let tax = data.federal_tax
  row(
    titled("TRIBUTAÇÃO FEDERAL (EXCETO CBS)"),
    field("IRRF", tax.irrf),
    field("Contribuição Previdenciária - Retida", tax.social_security),
    field("Contribuições Sociais - Retidas", tax.social_contributions),
    ..optional-row(tax.pis_cofins_row, pis-cofins => (
      field("PIS - Débito Apuração Própria", pis-cofins.pis),
      field("COFINS - Débito Apuração Própria", pis-cofins.cofins),
      span(2, field("Descrição Contrib. Sociais - Retidas", pis-cofins.social_contributions_description)),
    )),
  )
}

#let ibs-cbs = {
  let tax = data.ibs_cbs
  row(
    titled("TRIBUTAÇÃO IBS/CBS"),
    field("CST / cClassTrib", tax.cst_class),
    span(2, field(
      "Indicador de Operação / Código IBGE Incidência / Município Incidência / Sigla UF",
      tax.operation_incidence,
    )),
    field("Exclusões e Reduções da Base de Cálculo", tax.exclusions),
    field("Base de Cálculo Após Exclusões e Reduções", tax.base),
    field("Red. Alíquota IBS / Red. Alíquota CBS", tax.rate_reductions),
    field("Alíquota - IBS UF / IBS Mun", tax.state_municipal_rates),
    field("Alíq. Efetiva Municipal - IBS", tax.municipal_effective_rate),
    field("Valor Apurado Municipal - IBS", tax.municipal_amount),
    field("Alíq. Efetiva Estadual - IBS", tax.state_effective_rate),
    field("Valor Apurado Estadual - IBS", tax.state_amount),
    field("Valor Total Apurado - IBS", tax.ibs_total),
    field("Alíquota - CBS", tax.cbs_rate),
    field("Alíquota Efetiva - CBS", tax.cbs_effective_rate),
    field("Valor Total Apurado - CBS", tax.cbs_total),
  )
}

#let totals = {
  let totals = data.totals
  row(
    titled("VALOR TOTAL DA NFS-e"),
    field("VALOR DA OPERAÇÃO / SERVIÇO", totals.operation_value),
    field("Desconto Incondicionado", totals.unconditional_discount),
    field("Desconto Condicionado", totals.conditional_discount),
    field("Total das Retenções (ISSQN / Federais)", totals.retentions),
    field("VALOR LÍQUIDO DA NFS-e", totals.net_value),
    field("Total do IBS/CBS", totals.ibs_cbs_total),
    grid.cell(fill: cell-gray, field("VALOR LÍQUIDO DA NFS-e + IBS/CBS", totals.net_plus_ibs_cbs)),
  )
}

// Sem detalhes, o governo deixa uma linha em branco antes dos totais aproximados.
#let complementary(details) = {
  block(
    inset: (
      x: cell-padding,
      top: baseline-offset(arial, 7pt),
      bottom: descent(arial, 7pt) + row-padding,
    ),
    label-text("INFORMAÇÕES COMPLEMENTARES", size: 7pt),
  )
  block(
    inset: (x: cell-padding, top: baseline-offset(sans-serif, 7pt)),
    stack(
      spacing: line-pitch(sans-serif, 7pt),
      content-text(if details == none { "" } else { details }),
      content-text(data.complementary.approximate_taxes),
    ),
  )
}

// O canhoto tem borda de 1 pt por célula, e as células se sobrepõem em 1 pt como no PDF do governo.
#let stub = {
  let cells = (
    (page-left, column, "DATA CIENTIFICAÇÃO:", ""),
    (page-left + column, column, "IDENTIFICAÇÃO E ASSINATURA", ""),
    (page-left + 2 * column, 2 * column, "N° NFS-e / CHAVE NFS-e", data.stub),
  )
  for (x, width, name, value) in cells {
    at(x + 0.5pt, stub-top + 0.5pt, rect(width: width, height: stub-height - 1pt, stroke: 1pt))
    at(x + 1pt, stub-top + 1pt, block(width: width - 1pt, field(name, value)))
  }
}

// As linhas têm altura zero na linha de base; a margem inferior guarda o descendente da última
// linha para que ela não encoste no canhoto.
#set page(
  width: 595pt,
  height: 842pt,
  margin: (
    left: page-left,
    top: page-top,
    right: 595pt - page-left - 4 * column,
    bottom: 842pt - stub-top + descent(sans-serif, 7pt),
  ),
  background: {
    page-border
    if data.watermark != none { watermark(data.watermark) }
  },
)
#set text(
  size: 7pt,
  lang: "pt",
  fallback: false,
  kerning: false,
  ligatures: false,
  overhang: false,
  hyphenate: false,
  top-edge: "baseline",
  bottom-edge: "baseline",
)
#set par(linebreaks: "simple", justify: false, spacing: 0pt)
#set block(spacing: 0pt)

#let blocks-above-complementary(description) = {
  header
  divider
  identification
  divider
  provider
  divider
  party-section(
    "TOMADOR / ADQUIRENTE",
    data.taker,
    "TOMADOR/ADQUIRENTE DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e",
  )
  divider
  recipient
  divider
  party-section(
    "INTERMEDIÁRIO DA OPERAÇÃO",
    data.intermediary,
    "INTERMEDIÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e",
  )
  divider
  service(description)
  divider
  municipal-tax
  divider
  federal-tax
  divider
  ibs-cbs
  divider
  totals
  divider
}

// O maior começo do texto que ainda cabe, cortado com "..." como em NfseDanfse.Format.truncate/2.
#let shorten-to-fit(original, fits) = {
  let clusters = original.clusters()
  let cut(count) = (clusters.slice(0, count) + ("...",)).join()
  let (longest-fitting, shortest-overflowing) = (0, clusters.len())
  while shortest-overflowing - longest-fitting > 1 {
    let middle = calc.quo(longest-fitting + shortest-overflowing, 2)
    if fits(cut(middle)) { longest-fitting = middle } else { shortest-overflowing = middle }
  }
  cut(longest-fitting)
}

// O DANFSe tem uma página só. As informações complementares ficam com a altura que sobra acima do
// canhoto e são o primeiro texto a encolher (NT 008, item 2.5.3); se nem a linha mínima delas
// cabe, encolhe a descrição do serviço.
#qr-code
#stub
#layout(available => {
  let height-of(blocks) = measure(blocks, width: available.width).height
  let room-below(description) = available.height - height-of(blocks-above-complementary(description))
  let fits(room, details) = height-of(complementary(details)) <= room

  let description = data.service.description
  let details = data.complementary.details
  let shortest-details = if details == none { none } else { "..." }
  let room = room-below(description)
  if not fits(room, shortest-details) {
    description = shorten-to-fit(description, cut => fits(room-below(cut), shortest-details))
    room = room-below(description)
  }
  if details != none and not fits(room, details) {
    details = shorten-to-fit(details, cut => fits(room, cut))
  }

  blocks-above-complementary(description)
  complementary(details)
})
