defmodule NfseDanfse.Fields do
  @moduledoc false

  alias NfseDanfse.Descriptions
  alias NfseDanfse.Fields.Parties
  alias NfseDanfse.Fields.Taxes
  alias NfseDanfse.Format
  alias NfseDanfse.Places

  @type situation :: :cancelled | :replaced | nil

  @doc """
  Monta o texto final de cada campo do DANFSe da nota `nfse`, lida por
  `Nfse.Sefin.decode_nfse/1`, já formatado como o PDF do governo imprime: o template só posiciona.

  Campo ausente sai `"-"`; tomador, destinatário e intermediário ausentes saem `nil`, e o template
  imprime no lugar a linha de "NÃO IDENTIFICADO NA NFS-e". Linha que a NT 008 manda suprimir
  quando não tem dado sai `nil`.

  `situation` diz se a nota foi cancelada (`:cancelled`) ou substituída (`:replaced`): a NFS-e
  não carrega essa informação, e o DANFSe a mostra na marca d'água.
  """
  @spec build(struct(), situation()) :: map()
  def build(%{inf_nfse: inf_nfse}, situation) do
    inf_dps = inf_nfse.dps.inf_dps
    ibscbs = Taxes.ibs_cbs_group(inf_dps)
    identification = identification(inf_nfse, ibscbs)

    %{
      watermark: watermark(situation),
      header: header(inf_nfse),
      identification: identification,
      provider: Parties.provider(inf_nfse),
      taker: Parties.party(inf_dps.toma),
      recipient: recipient(ibscbs),
      recipient_is_taker: match?(%{ind_dest: "0"}, ibscbs),
      intermediary: Parties.party(inf_dps.interm),
      service: service(inf_nfse),
      municipal_tax: Taxes.municipal(inf_nfse),
      federal_tax: Taxes.federal(inf_nfse),
      ibs_cbs: Taxes.ibs_cbs(inf_nfse),
      totals: totals(inf_nfse),
      complementary: complementary(inf_nfse, ibscbs),
      stub: "#{identification.nfse_number} / #{identification.access_key}"
    }
  end

  defp watermark(nil), do: nil
  defp watermark(:cancelled), do: "CANCELADA"
  defp watermark(:replaced), do: "SUBSTITUÍDA"

  defp header(inf_nfse) do
    tp_amb = inf_nfse.dps.inf_dps.tp_amb

    %{
      municipality: header_municipality(inf_nfse),
      generating_environment: "Ambiente Gerador: #{inf_nfse.amb_ger}",
      environment: "Tipo de Ambiente: #{tp_amb}",
      without_legal_validity: tp_amb == "2"
    }
  end

  # A NT 008 (item 2.4.5) manda omitir o município do cabeçalho nos serviços do item 99 da lista.
  defp header_municipality(%{dps: %{inf_dps: %{serv: %{c_serv: %{c_trib_nac: "99" <> _}}}}}),
    do: nil

  defp header_municipality(inf_nfse),
    do: Format.text("Município: #{inf_nfse.x_loc_emi} - #{inf_nfse.emit.ender_nac.uf}")

  defp identification(inf_nfse, ibscbs) do
    inf_dps = inf_nfse.dps.inf_dps

    %{
      access_key: String.replace_prefix(inf_nfse.id, "NFS", ""),
      nfse_number: inf_nfse.n_nfse,
      competence: Format.date(inf_dps.d_compet),
      nfse_issued_at: Format.datetime(inf_nfse.dh_proc),
      dps_number: inf_dps.n_dps,
      dps_series: inf_dps.serie,
      dps_issued_at: Format.datetime(inf_dps.dh_emi),
      issuer: Descriptions.text(:tp_emit, inf_dps.tp_emit),
      status: Descriptions.text(:c_stat, inf_nfse.c_stat, 37),
      purpose: purpose(ibscbs)
    }
  end

  defp purpose(nil), do: "-"

  defp purpose(%{fin_nfse: purpose_code}), do: Descriptions.text(:fin_nfse, purpose_code, 37)

  defp recipient(nil), do: nil
  defp recipient(%{dest: recipient}), do: Parties.party(recipient)

  defp service(%{dps: %{inf_dps: %{serv: %{loc_prest: place, c_serv: code}}}} = inf_nfse) do
    %{
      tax_code:
        Enum.map_join(
          [national_tax_code(code.c_trib_nac), code.c_trib_mun],
          " / ",
          &Format.text/1
        ),
      nbs_code: nbs_code(code.c_nbs),
      location:
        Enum.map_join(
          [inf_nfse.x_loc_prestacao, Places.uf(place.c_loc_prestacao), place.c_pais_prestacao],
          " / ",
          &Format.text/1
        ),
      tax_code_description: Format.text(inf_nfse.x_trib_mun || inf_nfse.x_trib_nac, 167),
      description: Format.multiline_text(code.x_desc_serv, 1297)
    }
  end

  defp national_tax_code(<<item::binary-2, subitem::binary-2, detail::binary-2>>),
    do: "#{item}.#{subitem}.#{detail}"

  defp nbs_code(nil), do: "-"

  defp nbs_code(<<section::binary-1, position::binary-4, item::binary-2, subitem::binary-2>>),
    do: "#{section}.#{position}.#{item}.#{subitem}"

  defp totals(inf_nfse) do
    dps_amounts = inf_nfse.dps.inf_dps.valores
    discounts = dps_amounts.v_desc_cond_incond
    ibs_cbs_totals = get_in(Taxes.ibs_cbs_group(inf_nfse).tot_cibs)
    ibs_total = get_in(ibs_cbs_totals.g_ibs.v_ibs_tot) || Decimal.new(0)
    cbs_total = get_in(ibs_cbs_totals.g_cbs.v_cbs) || Decimal.new(0)

    %{
      operation_value: Format.money(dps_amounts.v_serv_prest.v_serv),
      unconditional_discount: Format.money(get_in(discounts.v_desc_incond)),
      conditional_discount: Format.money(get_in(discounts.v_desc_cond)),
      retentions: Format.money(inf_nfse.valores.v_total_ret),
      net_value: Format.money(inf_nfse.valores.v_liq),
      ibs_cbs_total: Format.money(Decimal.add(ibs_total, cbs_total)),
      net_plus_ibs_cbs: Format.money(get_in(ibs_cbs_totals.v_tot_nf) || Decimal.new(0))
    }
  end

  defp complementary(inf_nfse, ibscbs) do
    %{
      details: details(inf_nfse, ibscbs),
      approximate_taxes: approximate_taxes(inf_nfse.dps.inf_dps.valores.trib.tot_trib)
    }
  end

  defp approximate_taxes(%{v_tot_trib: amounts, p_tot_trib: rates}) do
    federal = approximate_tax(get_in(amounts.v_tot_trib_fed), get_in(rates.p_tot_trib_fed))
    state = approximate_tax(get_in(amounts.v_tot_trib_est), get_in(rates.p_tot_trib_est))
    municipal = approximate_tax(get_in(amounts.v_tot_trib_mun), get_in(rates.p_tot_trib_mun))

    "Totais aproximados dos Tributos cfe. Lei n° 12.741/2012: " <>
      "Federais: #{federal}; Estaduais: #{state}; Municipais: #{municipal};"
  end

  # O pTotTribSN do Simples Nacional fica de fora: o DANFSe do governo imprime traço com ele.
  defp approximate_tax(nil, rate), do: Format.percent(rate)
  defp approximate_tax(amount, _rate), do: Format.money(amount)

  defp details(inf_nfse, ibscbs) do
    parts = detail_parts(inf_nfse, ibscbs)

    case Enum.reject(parts, fn {_label, value} -> value in [nil, ""] end) do
      [] ->
        nil

      filled_parts ->
        filled_parts
        |> Enum.map_join(" | ", fn {label, value} -> "#{label}: #{value}" end)
        |> Format.multiline_text(1997)
    end
  end

  # Ordem e rótulos da NT 008, item 2.4.5.
  defp detail_parts(%{dps: %{inf_dps: inf_dps}} = inf_nfse, ibscbs) do
    service = inf_dps.serv
    complement = service.info_compl
    work = service.obra

    [
      {"Inf. Cont.", get_in(complement.x_inf_comp)},
      {"NFS-e Subst.", get_in(inf_dps.subst.ch_substda)},
      {"Doc. Ref.", get_in(complement.doc_ref)},
      {"Cod. Obra", get_in(work.c_obra)},
      {"Insc. Imob.", get_in(work.insc_imob_fisc) || get_in(ibscbs.imovel.insc_imob_fisc)},
      {"Cod. Evt.", event_id(service.atv_evento)},
      {"Doc. Tec.", get_in(complement.id_doc_tec)},
      {"Núm. Ped.", field(complement, :x_ped)},
      {"Item Ped.", order_items(get_in(field(complement, :g_item_ped).x_item_ped))},
      {"Inf. A. T. Mun.", municipal_tax_information(inf_nfse)}
    ]
  end

  # A NFS-e 1.00 guarda o xOutInf dentro de `valores`.
  defp municipal_tax_information(inf_nfse),
    do: field(inf_nfse, :x_out_inf) || field(inf_nfse.valores, :x_out_inf)

  # O leiaute 1.01 renomeou o `id` da atividade de evento para `idAtvEvt`.
  defp event_id(%{id_atv_evt: id}), do: id
  defp event_id(event), do: get_in(event.id)

  defp order_items(nil), do: nil
  defp order_items(items), do: Enum.join(items, ", ")

  # Só para os campos que um dos leiautes não tem no struct; os demais usam acesso direto, que
  # quebra num nome errado em vez de imprimir traço.
  defp field(nil, _name), do: nil
  defp field(group, name), do: Map.get(group, name)
end
