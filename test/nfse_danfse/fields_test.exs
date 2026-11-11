defmodule NfseDanfse.FieldsTest do
  use ExUnit.Case, async: true

  alias Nfse.Schema.V1_00
  alias Nfse.Schema.V1_01.TCExigSuspensa
  alias Nfse.Schema.V1_01.TCRTCInfoImovel
  alias NfseDanfse.Fields
  alias NfseDanfse.Fixtures

  describe "fills the header, identification and parties the way the government DANFSe prints them" do
    test "fills header, identification and parties of an ME/EPP note as the government prints them" do
      fields = Fields.build(Fixtures.decode!("me_epp"), nil)

      assert fields.watermark == nil

      assert fields.header == %{
               municipality: "Município: Salvador - BA",
               generating_environment: "Ambiente Gerador: 2",
               environment: "Tipo de Ambiente: 1",
               without_legal_validity: false
             }

      assert fields.identification == %{
               access_key: "29274082211222333000181000000000001226119876543214",
               nfse_number: "12",
               competence: "09/11/2026",
               nfse_issued_at: "09/11/2026 14:20:15",
               dps_number: "12",
               dps_series: "365",
               dps_issued_at: "09/11/2026 14:19:40",
               issuer: "Prestador",
               status: "NFS-e Gerada",
               purpose: "-"
             }

      assert fields.provider == %{
               document: "11.222.333/0001-81",
               municipal_registration: "-",
               phone: "-",
               name: "Studio Ana",
               municipality: "Salvador / BA",
               ibge_cep: "29.27408 / 40.000-000",
               address: "Rua das Flores, 100, Centro",
               email: "-",
               simples_nacional: "Optante - Microempresa ou Empresa de ...",
               simples_regime:
                 "Regime de apuração dos tributos federais e municipal pelo Simples Nacional"
             }

      assert fields.taker == %{
               document: "529.982.247-25",
               municipal_registration: "-",
               phone: "-",
               name: "Ana Souza",
               municipality: "-",
               ibge_cep: "-",
               address: "-",
               email: "-"
             }

      assert fields.recipient == nil
      refute fields.recipient_is_taker
      assert fields.intermediary == nil
      assert fields.stub == "12 / 29274082211222333000181000000000001226119876543214"
    end

    test "fills every party of a complete homologation note" do
      fields = Fields.build(Fixtures.decode!("complete"), nil)

      assert fields.header.environment == "Tipo de Ambiente: 2"
      assert fields.header.without_legal_validity
      assert fields.identification.issuer == "Prestador"
      assert fields.identification.status == "NFS-e de Decisão Judicial ou Administ..."
      assert fields.identification.purpose == "NFS-e regular"

      assert fields.provider == %{
               document: "11.222.333/0001-81",
               municipal_registration: "123456",
               phone: "71999990000",
               name: "Studio Ana",
               municipality: "Salvador / BA",
               ibge_cep: "29.27408 / 40.000-000",
               address: "Avenida das Palmeiras, 200, Sala 12, Jardim Exemplo",
               email: "contato@studioana.example",
               simples_nacional: "Não Optante",
               simples_regime: "-"
             }

      assert fields.taker == %{
               document: "11.444.777/0001-61",
               municipal_registration: "7654321",
               phone: "11988887777",
               name: "Clínica Exemplo Ltda",
               municipality: "São Paulo / SP",
               ibge_cep: "35.50308 / 01.310-100",
               address: "Avenida Exemplo, 1000, Bela Vista",
               email: "contas@clinicaexemplo.example"
             }

      assert fields.recipient == %{
               document: "999999990",
               phone: "351900000000",
               name: "Maria Exemplo",
               municipality: "Vila Nova de Gaia / Distrito do Po...",
               ibge_cep: "- / 4400-001",
               address: "Rua Exemplo, 1, Centro",
               email: "maria@destinatario.example"
             }

      refute fields.recipient_is_taker

      assert fields.intermediary == %{
               document: "111.444.777-35",
               municipal_registration: "-",
               phone: "71988886666",
               name: "João Exemplo",
               municipality: "Salvador / BA",
               ibge_cep: "29.27408 / 40.140-000",
               address: "Rua Exemplo, 10, Barra",
               email: "joao@intermediario.example"
             }
    end

    test "reads the provider from the DPS when the taker issued the note" do
      me_epp = Fixtures.decode!("me_epp")

      taker_as_emitter = %{
        me_epp.inf_nfse.emit
        | cnpj: nil,
          cpf: "52998224725",
          im: "555",
          x_nome: "Ana Souza",
          fone: "71977776666",
          email: "ana@tomador.example",
          ender_nac: %{me_epp.inf_nfse.emit.ender_nac | x_lgr: "Rua dos Tomadores", nro: "50"}
      }

      taker_issued = put_in(me_epp.inf_nfse.emit, taker_as_emitter)
      taker_issued = put_in(taker_issued.inf_nfse.dps.inf_dps.tp_emit, "2")
      taker_issued = put_in(taker_issued.inf_nfse.dps.inf_dps.prest.x_nome, "Studio Ana")

      fields = Fields.build(taker_issued, nil)

      assert fields.identification.issuer == "Tomador"

      assert fields.provider == %{
               document: "11.222.333/0001-81",
               municipal_registration: "-",
               phone: "-",
               name: "Studio Ana",
               municipality: "-",
               ibge_cep: "-",
               address: "-",
               email: "-",
               simples_nacional: "Optante - Microempresa ou Empresa de ...",
               simples_regime:
                 "Regime de apuração dos tributos federais e municipal pelo Simples Nacional"
             }
    end

    test "marks a note without taker and cancelled or replaced notes" do
      me_epp = Fixtures.decode!("me_epp")

      without_taker = put_in(me_epp.inf_nfse.dps.inf_dps.toma, nil)
      assert Fields.build(without_taker, nil).taker == nil

      assert Fields.build(me_epp, :cancelled).watermark == "CANCELADA"
      assert Fields.build(me_epp, :replaced).watermark == "SUBSTITUÍDA"

      item_99_service = put_in(me_epp.inf_nfse.dps.inf_dps.serv.c_serv.c_trib_nac, "990101")
      assert Fields.build(item_99_service, nil).header.municipality == nil
    end

    test "tells that the recipient is the taker when the note says so" do
      complete = Fixtures.decode!("complete")
      recipient_is_taker = %{complete.inf_nfse.dps.inf_dps.ibscbs | ind_dest: "0", dest: nil}

      fields =
        Fields.build(put_in(complete.inf_nfse.dps.inf_dps.ibscbs, recipient_is_taker), nil)

      assert fields.recipient == nil
      assert fields.recipient_is_taker
    end

    test "prints raw codes and dashes where the note lacks what the DANFSe shows" do
      complete = Fixtures.decode!("complete")
      intermediary = complete.inf_nfse.dps.inf_dps.interm

      unidentified_intermediary = %{
        put_in(intermediary.end.end_nac.c_mun, "9999999")
        | cpf: nil,
          c_nao_nif: "1"
      }

      fields =
        Fields.build(put_in(complete.inf_nfse.dps.inf_dps.interm, unidentified_intermediary), nil)

      assert fields.intermediary.document == "-"
      assert fields.intermediary.municipality == "9999999"
      assert fields.intermediary.ibge_cep == "99.99999 / 40.140-000"
    end
  end

  describe "fills service, taxes, totals and complementary information the way the government DANFSe prints them" do
    test "fills service, taxes and totals of an ME/EPP note as the government prints them" do
      fields = Fields.build(Fixtures.decode!("me_epp"), nil)

      assert fields.service.tax_code == "01.04.01 / -"
      assert fields.service.location == "Salvador / BA / -"
      assert String.ends_with?(fields.service.tax_code_description, "será executado, incl...")
      assert fields.municipal_tax.taxation_type == "Operação Tributável"
      assert fields.municipal_tax.incidence == "Salvador / BA / -"
      assert fields.municipal_tax.special_regime_row == nil
      assert fields.municipal_tax.benefit_row == nil
      assert fields.municipal_tax.retention == "Não Retido"

      assert fields.federal_tax.pis_cofins_row == %{
               pis: "-",
               cofins: "-",
               social_contributions_description: "-"
             }

      assert fields.ibs_cbs.cst_class == "- / -"
      assert fields.ibs_cbs.operation_incidence == "- / - / - / -"
      assert fields.ibs_cbs.rate_reductions == "- / - / -"
      assert fields.ibs_cbs.state_municipal_rates == "- / -"
      assert fields.ibs_cbs.exclusions == "R$ 0,00"

      assert fields.totals == %{
               operation_value: "R$ 26,91",
               unconditional_discount: "-",
               conditional_discount: "-",
               retentions: "-",
               net_value: "R$ 26,91",
               ibs_cbs_total: "R$ 0,00",
               net_plus_ibs_cbs: "R$ 0,00"
             }

      assert fields.complementary.details == nil

      assert fields.complementary.approximate_taxes ==
               "Totais aproximados dos Tributos cfe. Lei n° 12.741/2012: Federais: -; Estaduais: -; Municipais: -;"
    end

    test "fills every tax block of a complete note" do
      fields = Fields.build(Fixtures.decode!("complete"), nil)

      assert fields.service == %{
               tax_code: "06.01.01 / 001",
               nbs_code: "1.2602.10.00",
               location: "Salvador / BA / -",
               tax_code_description: "Cabeleireiro, manicure e pedicure.",
               description: "Corte, escova e manicure para a equipe no evento corporativo."
             }

      assert fields.municipal_tax == %{
               taxation_type: "Operação Tributável",
               incidence: "Salvador / BA / -",
               special_regime_row: nil,
               benefit_row: %{
                 benefit: "-",
                 benefit_calculation: "-",
                 deductions: "R$ 100,00",
                 unconditional_discount: "R$ 50,00"
               },
               base: "R$ 850,00",
               rate: "5,00%",
               retention: "Retido pelo Tomador",
               issqn: "R$ 42,50"
             }

      assert fields.federal_tax == %{
               irrf: "R$ 12,75",
               social_security: "R$ 11,00",
               social_contributions: "R$ 8,50",
               pis_cofins_row: %{
                 pis: "R$ 5,53",
                 cofins: "R$ 25,50",
                 social_contributions_description: "PIS/COFINS/CSLL Retidos"
               }
             }

      assert fields.ibs_cbs == %{
               cst_class: "000 / 000001",
               operation_incidence: "100301 / 2927408 / Salvador / BA",
               exclusions: "R$ 123,53",
               base: "R$ 850,00",
               rate_reductions: "10,00% / 10,00% / 10,00%",
               state_municipal_rates: "0,10% / 0,00%",
               municipal_effective_rate: "0,00%",
               municipal_amount: "R$ 0,00",
               state_effective_rate: "0,09%",
               state_amount: "R$ 0,77",
               ibs_total: "R$ 0,77",
               cbs_rate: "0,90%",
               cbs_effective_rate: "0,81%",
               cbs_total: "R$ 6,89"
             }

      assert fields.totals == %{
               operation_value: "R$ 1.000,00",
               unconditional_discount: "R$ 50,00",
               conditional_discount: "R$ 20,00",
               retentions: "R$ 105,78",
               net_value: "R$ 824,22",
               ibs_cbs_total: "R$ 7,66",
               net_plus_ibs_cbs: "R$ 824,22"
             }

      assert fields.complementary.details ==
               "Inf. Cont.: Atendimento realizado no evento corporativo do cliente." <>
                 " | NFS-e Subst.: 29274082211222333000181000000000001126115555555551" <>
                 " | Doc. Ref.: Contrato 2026/15 | Cod. Obra: OBRA2026001" <>
                 " | Insc. Imob.: IMOB123456 | Cod. Evt.: EVT2026001 | Doc. Tec.: DRT001" <>
                 " | Núm. Ped.: PED4521 | Item Ped.: 1" <>
                 " | Inf. A. T. Mun.: Nota de teste emitida em homologação."

      assert fields.complementary.approximate_taxes ==
               "Totais aproximados dos Tributos cfe. Lei n° 12.741/2012: " <>
                 "Federais: R$ 150,00; Estaduais: R$ 0,00; Municipais: R$ 42,50;"
    end

    test "prints the special regime row of a professional society with suspended ISSQN" do
      complete = Fixtures.decode!("complete")

      professional_society =
        put_in(complete.inf_nfse.dps.inf_dps.prest.reg_trib.reg_esp_trib, "6")

      suspended =
        put_in(
          professional_society.inf_nfse.dps.inf_dps.valores.trib.trib_mun.exig_susp,
          %TCExigSuspensa{tp_susp: "2", n_processo: "PROC2026001"}
        )

      assert Fields.build(suspended, nil).municipal_tax.special_regime_row == %{
               special_regime: "Sociedade de Profissionais",
               immunity: "-",
               suspension: "Exigibilidade Suspensa por Processo A...",
               suspension_process: "PROC2026001"
             }
    end

    test "replaces the ISSQN block of a note not subject to the ISSQN" do
      me_epp = Fixtures.decode!("me_epp")
      not_subject = put_in(me_epp.inf_nfse.dps.inf_dps.valores.trib.trib_mun.trib_issqn, "4")

      assert Fields.build(not_subject, nil).municipal_tax == nil
    end

    test "reads the property registration of a real estate operation without a construction work" do
      complete = Fixtures.decode!("complete")
      without_work = put_in(complete.inf_nfse.dps.inf_dps.serv.obra, nil)

      real_estate =
        put_in(
          without_work.inf_nfse.dps.inf_dps.ibscbs.imovel,
          %TCRTCInfoImovel{insc_imob_fisc: "IMOB654321", c_cib: "12345678"}
        )

      details = Fields.build(real_estate, nil).complementary.details

      assert details =~ " | Doc. Ref.: Contrato 2026/15 | Insc. Imob.: IMOB654321 | Cod. Evt.: "
    end

    test "cuts long texts at the government limits" do
      fields = Fields.build(Fixtures.decode!("long_texts"), nil)

      assert String.length(fields.service.description) == 1300
      assert String.length(fields.service.tax_code_description) == 170
      assert String.length(fields.complementary.details) == 2000
      assert String.length(fields.taker.name) == 80
      assert String.ends_with?(fields.service.description, "...")
      assert String.ends_with?(fields.service.tax_code_description, "...")
      assert String.ends_with?(fields.complementary.details, "...")
      assert String.ends_with?(fields.taker.name, "...")
    end

    test "prints every field on one line except the service description and the complementary information" do
      note = Fixtures.decode!("complete")
      note = put_in(note.inf_nfse.dps.inf_dps.toma.x_nome, "Clínica\nExemplo\r\nLtda")
      note = put_in(note.inf_nfse.dps.inf_dps.toma.end.x_lgr, "Avenida\n\tExemplo")
      note = put_in(note.inf_nfse.x_trib_mun, "Cabeleireiro,\nmanicure e pedicure.")
      note = put_in(note.inf_nfse.x_loc_incid, "Salvador\n")
      note = put_in(note.inf_nfse.dps.inf_dps.serv.c_serv.x_desc_serv, "Corte\nEscova")
      note = put_in(note.inf_nfse.dps.inf_dps.serv.info_compl.x_inf_comp, "Equipe A\nEquipe B")

      fields = Fields.build(note, nil)

      assert fields.taker.name == "Clínica Exemplo Ltda"
      assert fields.taker.address == "Avenida Exemplo, 1000, Bela Vista"
      assert fields.service.tax_code_description == "Cabeleireiro, manicure e pedicure."
      assert fields.municipal_tax.incidence == "Salvador / BA / -"
      assert fields.service.description == "Corte\nEscova"
      assert fields.complementary.details =~ "Inf. Cont.: Equipe A\nEquipe B | "
    end

    test "drops the PIS and COFINS line after 2026" do
      me_epp = Fixtures.decode!("me_epp")

      last_day_of_2026 = put_in(me_epp.inf_nfse.dps.inf_dps.d_compet, ~D[2026-12-31])
      assert Fields.build(last_day_of_2026, nil).federal_tax.pis_cofins_row != nil

      first_day_of_2027 = put_in(me_epp.inf_nfse.dps.inf_dps.d_compet, ~D[2027-01-01])

      assert Fields.build(first_day_of_2027, nil).federal_tax == %{
               irrf: "-",
               social_security: "-",
               social_contributions: "-",
               pis_cofins_row: nil
             }
    end

    test "reads a 1.00 note without the IBS/CBS group" do
      v1_00 = Fixtures.decode!("v1_00")
      fields = Fields.build(v1_00, nil)

      assert fields.ibs_cbs.cst_class == "- / -"
      assert fields.ibs_cbs.operation_incidence == "- / - / - / -"
      assert fields.identification.purpose == "-"
      assert fields.service.tax_code == "06.01.01 / -"
      assert fields.totals.net_value == "R$ 49,90"
      assert fields.totals.ibs_cbs_total == "R$ 0,00"
      assert fields.complementary.details == nil

      with_event =
        put_in(v1_00.inf_nfse.dps.inf_dps.serv.atv_evento, %V1_00.TCAtvEvento{id: "EVT2026002"})

      with_municipal_info =
        put_in(with_event.inf_nfse.valores.x_out_inf, "Nota de teste no leiaute 1.00.")

      assert Fields.build(with_municipal_info, nil).complementary.details ==
               "Cod. Evt.: EVT2026002 | Inf. A. T. Mun.: Nota de teste no leiaute 1.00."
    end
  end
end
