defmodule NfseDanfse.FormatTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.Format

  describe "formats values the way the government DANFSe prints them" do
    test "masks documents, postal code and IBGE code" do
      assert Format.cnpj("11222333000181") == "11.222.333/0001-81"
      assert Format.cpf("52998224725") == "529.982.247-25"
      assert Format.cep("40000000") == "40.000-000"
      assert Format.ibge_code("2927408") == "29.27408"
    end

    test "prints money and rates with thousands separator and two decimals, dashed when absent" do
      assert Format.money(Decimal.new("26.91")) == "R$ 26,91"
      assert Format.money(Decimal.new("1234567.8")) == "R$ 1.234.567,80"
      assert Format.money(Decimal.new("0")) == "R$ 0,00"
      assert Format.money(nil) == "-"
      assert Format.percent(Decimal.new("5")) == "5,00%"
      assert Format.percent(nil) == "-"
    end

    test "prints dates in Brasilia time even when the instant is already the next day in UTC" do
      assert Format.date(~D[2026-11-09]) == "09/11/2026"
      assert Format.datetime(~U[2026-11-10 01:20:15Z]) == "09/11/2026 22:20:15"
      assert Format.datetime(~U[2026-11-10 02:30:00Z]) == "09/11/2026 23:30:00"
    end

    test "cuts long text the way the government does and keeps short text intact" do
      assert Format.truncate("Optante - Microempresa ou Empresa de Pequeno Porte (ME/EPP)", 37) ==
               "Optante - Microempresa ou Empresa de ..."

      assert Format.truncate("Prestador", 37) == "Prestador"
    end

    test "drops characters the PDF cannot encode and dashes empty values" do
      assert Format.printable("Ana 💇 Souza #1 <%= x %>") == "Ana  Souza #1 <%= x %>"
      assert Format.printable("Atenção – “aspas” €") == "Atenção – “aspas” €"
      assert Format.printable("linha 1\nlinha 2") == "linha 1\nlinha 2"
      assert Format.or_dash(nil) == "-"
      assert Format.or_dash("") == "-"
      assert Format.or_dash("365") == "365"
    end

    test "prints free text without unencodable characters, cut at the limit and dashed when absent" do
      assert Format.text("Ana 💇 Souza") == "Ana  Souza"
      assert Format.text("💇") == "-"
      assert Format.text(nil) == "-"
      assert Format.text("Clínica Exemplo Ltda", 7) == "Clínica..."
      assert Format.text("Studio Ana", 77) == "Studio Ana"
      assert Format.text(nil, 77) == "-"
    end

    test "prints a single-line field on one line and keeps the line breaks of multiline text" do
      assert Format.text("Clínica\nExemplo\r\nLtda") == "Clínica Exemplo Ltda"

      assert Format.text("Avenida Exemplo, 1000 \n\t Bela Vista\n") ==
               "Avenida Exemplo, 1000 Bela Vista"

      assert Format.text("\n") == "-"
      assert Format.text("Studio\tAna", 77) == "Studio Ana"

      assert Format.multiline_text("Corte\r\nEscova 💇\nManicure", 1297) ==
               "Corte\nEscova \nManicure"

      assert Format.multiline_text("Corte, escova e manicure", 5) == "Corte..."
      assert Format.multiline_text("Corte\tEscova\rManicure", 1297) == "Corte Escova\nManicure"
    end

    test "keeps the accents of a name whose letters come decomposed" do
      decomposed = String.normalize("João Conceição", :nfd)

      refute decomposed == "João Conceição"
      assert Format.text(decomposed) == "João Conceição"
    end

    test "raises a typed error carrying its kind and cause" do
      error = %NfseDanfse.Error{kind: :invalid_xml, message: "XML inválido", cause: :boom}

      assert Exception.message(error) == "XML inválido"
      assert error.kind == :invalid_xml
      assert error.cause == :boom
    end
  end
end
