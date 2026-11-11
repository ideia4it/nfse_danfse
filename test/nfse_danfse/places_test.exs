defmodule NfseDanfse.PlacesTest do
  use ExUnit.Case, async: true

  alias NfseDanfse.Places

  describe "looks up municipalities the way the government DANFSe prints them" do
    test "finds the name and state of a municipality by its IBGE code" do
      assert Places.municipality("2927408") == {:ok, %{name: "Salvador", uf: "BA"}}
      assert Places.municipality("3550308") == {:ok, %{name: "São Paulo", uf: "SP"}}
      assert Places.municipality("9999999") == :error
    end

    test "finds the state of a municipality and nothing for a missing or unknown code" do
      assert Places.uf("2927408") == "BA"
      assert Places.uf("9999999") == nil
      assert Places.uf(nil) == nil
    end
  end
end
