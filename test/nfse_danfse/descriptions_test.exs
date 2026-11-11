defmodule NfseDanfse.DescriptionsTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.Descriptions

  describe "describes codes the way the government DANFSe prints them" do
    test "describes codes with the government wording and falls back to the raw code" do
      assert Descriptions.describe(:tp_emit, "1") == "Prestador"
      assert Descriptions.describe(:c_stat, "100") == "NFS-e Gerada"

      assert Descriptions.describe(:op_simp_nac, "3") ==
               "Optante - Microempresa ou Empresa de Pequeno Porte (ME/EPP)"

      assert Descriptions.describe(:reg_ap_trib_sn, "1") ==
               "Regime de apuração dos tributos federais e municipal pelo Simples Nacional"

      assert Descriptions.describe(:trib_issqn, "1") == "Operação Tributável"
      assert Descriptions.describe(:tp_ret_issqn, "1") == "Não Retido"
      assert Descriptions.describe(:reg_esp_trib, "0") == nil
      assert Descriptions.describe(:c_stat, "999") == "999"
      assert Descriptions.describe(:tp_emit, nil) == nil
    end

    test "describes every code of the remaining fields" do
      assert Descriptions.describe(:tp_emit, "3") == "Intermediário"
      assert Descriptions.describe(:c_stat, "103") == "NFS-e Avulsa"
      assert Descriptions.describe(:c_stat, "107") == "NFS-e MEI"
      assert Descriptions.describe(:fin_nfse, "0") == "NFS-e regular"
      assert Descriptions.describe(:reg_esp_trib, "6") == "Sociedade de Profissionais"
      assert Descriptions.describe(:trib_issqn, "3") == "Exportação de Serviço"
      assert Descriptions.describe(:tp_ret_issqn, "3") == "Retido pelo Intermediario"

      assert Descriptions.describe(:tp_imunidade, "2") ==
               "Templos de qualquer culto (CF88, Art 150, VI, b)"

      assert Descriptions.describe(:tp_susp, "1") == "Exigibilidade Suspensa por Decisão Judicial"
      assert Descriptions.describe(:tp_bm, "2") == "Redução da BC em percentual"

      assert Descriptions.describe(:tp_ret_pis_cofins, "9") ==
               "COFINS Não Retido, PIS/CSLL Retidos"

      assert Descriptions.describe(:unknown_field, "1") == "1"
    end

    test "prints the description dashed when absent and cut at the field limit" do
      assert Descriptions.text(:tp_emit, "1") == "Prestador"
      assert Descriptions.text(:reg_esp_trib, "0") == "-"
      assert Descriptions.text(:tp_susp, nil, 37) == "-"

      assert Descriptions.text(:op_simp_nac, "3", 37) ==
               "Optante - Microempresa ou Empresa de ..."
    end
  end
end
