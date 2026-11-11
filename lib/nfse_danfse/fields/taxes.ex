defmodule NfseDanfse.Fields.Taxes do
  @moduledoc false

  alias NfseDanfse.Descriptions
  alias NfseDanfse.Format
  alias NfseDanfse.Places

  # A NT 008 (nota 6) só imprime a linha de PIS e COFINS até a competência de 2026.
  @last_year_with_pis_cofins 2026

  @doc """
  Campos da tributação municipal (ISSQN), ou `nil` na operação de não incidência do ISSQN, em que
  o template imprime no lugar a linha de "OPERAÇÃO NÃO SUJEITA AO ISSQN" (NT 008, nota 4).
  """
  @spec municipal(struct()) :: map() | nil
  def municipal(%{dps: %{inf_dps: %{valores: %{trib: %{trib_mun: %{trib_issqn: "4"}}}}}}),
    do: nil

  def municipal(%{dps: %{inf_dps: inf_dps}, valores: nfse_amounts} = inf_nfse) do
    municipal_tax = inf_dps.valores.trib.trib_mun

    %{
      taxation_type: Descriptions.text(:trib_issqn, municipal_tax.trib_issqn),
      incidence:
        Enum.map_join(
          [inf_nfse.x_loc_incid, Places.uf(inf_nfse.c_loc_incid), municipal_tax.c_pais_result],
          " / ",
          &Format.text/1
        ),
      special_regime_row: special_regime_row(inf_dps.prest.reg_trib, municipal_tax),
      benefit_row: benefit_row(inf_nfse, municipal_tax),
      base: Format.money(nfse_amounts.v_bc),
      rate: Format.percent(nfse_amounts.p_aliq_aplic),
      retention: Descriptions.text(:tp_ret_issqn, municipal_tax.tp_ret_issqn),
      issqn: Format.money(nfse_amounts.v_issqn)
    }
  end

  @doc """
  Campos da tributação federal, sem a CBS.
  """
  @spec federal(struct()) :: map()
  def federal(%{dps: %{inf_dps: inf_dps}}) do
    federal_tax = inf_dps.valores.trib.trib_fed

    %{
      irrf: Format.money(get_in(federal_tax.v_ret_irrf)),
      social_security: Format.money(get_in(federal_tax.v_ret_cp)),
      social_contributions: Format.money(get_in(federal_tax.v_ret_csll)),
      pis_cofins_row: pis_cofins_row(inf_dps.d_compet, get_in(federal_tax.piscofins))
    }
  end

  @doc """
  Campos da tributação do IBS e da CBS. Sem o grupo `IBSCBS`, saem os traços e zeros que o
  DANFSe do governo imprime.
  """
  @spec ibs_cbs(struct()) :: map()
  def ibs_cbs(inf_nfse) do
    requested = ibs_cbs_group(inf_nfse.dps.inf_dps)
    calculated = ibs_cbs_group(inf_nfse)
    classification = get_in(requested.valores.trib.g_ibscbs)
    rates = get_in(calculated.valores)
    totals = get_in(calculated.tot_cibs)

    %{
      cst_class:
        Enum.map_join(
          [get_in(classification.cst), get_in(classification.c_class_trib)],
          " / ",
          &Format.text/1
        ),
      operation_incidence: operation_incidence(requested, calculated),
      exclusions: exclusions(inf_nfse),
      base: Format.money(get_in(rates.v_bc)),
      rate_reductions:
        Enum.map_join(
          [
            get_in(rates.uf.p_red_aliq_uf),
            get_in(rates.mun.p_red_aliq_mun),
            get_in(rates.fed.p_red_aliq_cbs)
          ],
          " / ",
          &Format.percent/1
        ),
      state_municipal_rates:
        Enum.map_join(
          [get_in(rates.uf.p_ibsuf), get_in(rates.mun.p_ibs_mun)],
          " / ",
          &Format.percent/1
        ),
      municipal_effective_rate: Format.percent(get_in(rates.mun.p_aliq_efet_mun)),
      municipal_amount: Format.money(get_in(totals.g_ibs.g_ibs_mun_tot.v_ibs_mun)),
      state_effective_rate: Format.percent(get_in(rates.uf.p_aliq_efet_uf)),
      state_amount: Format.money(get_in(totals.g_ibs.g_ibsuf_tot.v_ibsuf)),
      ibs_total: Format.money(get_in(totals.g_ibs.v_ibs_tot)),
      cbs_rate: Format.percent(get_in(rates.fed.p_cbs)),
      cbs_effective_rate: Format.percent(get_in(rates.fed.p_aliq_efet_cbs)),
      cbs_total: Format.money(get_in(totals.g_cbs.v_cbs))
    }
  end

  @doc """
  O grupo `IBSCBS` da NFS-e (`infNFSe`) ou da DPS (`infDPS`), ou `nil` quando a nota não o traz.

  A NFS-e 1.00 não tem o grupo nem o campo no struct, por isso a leitura passa sempre por aqui.
  """
  @spec ibs_cbs_group(struct()) :: struct() | nil
  def ibs_cbs_group(nfse_or_dps), do: Map.get(nfse_or_dps, :ibscbs)

  defp special_regime_row(tax_regime, municipal_tax) do
    omit_blank_row(%{
      special_regime: Descriptions.text(:reg_esp_trib, tax_regime.reg_esp_trib),
      immunity: Descriptions.text(:tp_imunidade, municipal_tax.tp_imunidade, 37),
      suspension: Descriptions.text(:tp_susp, get_in(municipal_tax.exig_susp.tp_susp), 37),
      suspension_process: Format.text(get_in(municipal_tax.exig_susp.n_processo))
    })
  end

  defp benefit_row(inf_nfse, municipal_tax) do
    dps_amounts = inf_nfse.dps.inf_dps.valores
    nfse_amounts = inf_nfse.valores

    deductions =
      sum([
        nfse_amounts.v_calc_dr || get_in(dps_amounts.v_ded_red.v_dr),
        reimbursements(inf_nfse)
      ])

    omit_blank_row(%{
      benefit: Descriptions.text(:tp_bm, nfse_amounts.tp_bm),
      benefit_calculation:
        Format.money(nfse_amounts.v_calc_bm || get_in(municipal_tax.bm.v_red_bcbm)),
      deductions: Format.money(deductions),
      unconditional_discount: Format.money(get_in(dps_amounts.v_desc_cond_incond.v_desc_incond))
    })
  end

  # A NT 008 (nota 5) suprime a linha quando nenhum dos campos dela tem dado.
  defp omit_blank_row(row) do
    if Enum.all?(Map.values(row), &(&1 == "-")), do: nil, else: row
  end

  defp pis_cofins_row(%Date{year: year}, _pis_cofins) when year > @last_year_with_pis_cofins,
    do: nil

  defp pis_cofins_row(_competence, pis_cofins) do
    %{
      pis: Format.money(get_in(pis_cofins.v_pis)),
      cofins: Format.money(get_in(pis_cofins.v_cofins)),
      social_contributions_description:
        Descriptions.text(:tp_ret_pis_cofins, get_in(pis_cofins.tp_ret_pis_cofins))
    }
  end

  defp operation_incidence(requested, calculated) do
    municipality_code = get_in(calculated.c_localidade_incid)

    Enum.map_join(
      [
        get_in(requested.c_ind_op),
        municipality_code,
        get_in(calculated.x_localidade_incid),
        Places.uf(municipality_code)
      ],
      " / ",
      &Format.text/1
    )
  end

  defp exclusions(inf_nfse) do
    dps_amounts = inf_nfse.dps.inf_dps.valores
    pis_cofins = get_in(dps_amounts.trib.trib_fed.piscofins)

    excluded =
      sum([
        get_in(dps_amounts.v_desc_cond_incond.v_desc_incond),
        reimbursements(inf_nfse),
        inf_nfse.valores.v_issqn,
        get_in(pis_cofins.v_pis),
        get_in(pis_cofins.v_cofins)
      ])

    Format.money(excluded || Decimal.new(0))
  end

  defp reimbursements(inf_nfse), do: get_in(ibs_cbs_group(inf_nfse).valores.v_calc_ree_rep_res)

  defp sum(amounts) do
    case Enum.reject(amounts, &is_nil/1) do
      [] -> nil
      present -> Enum.reduce(present, &Decimal.add/2)
    end
  end
end
