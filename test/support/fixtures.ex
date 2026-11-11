defmodule NfseDanfse.Fixtures do
  @moduledoc """
  Notas fictícias do Studio Ana guardadas em `test/fixtures`.
  """

  @fixtures_dir Path.expand("../fixtures", __DIR__)

  @doc "O XML da fixture `name`, sem a extensão."
  @spec read!(String.t()) :: binary()
  def read!(name), do: File.read!(Path.join(@fixtures_dir, name <> ".xml"))

  @doc "A fixture `name` lida por `Nfse.Sefin.decode_nfse/1`."
  @spec decode!(String.t()) :: struct()
  def decode!(name) do
    {:ok, nfse} = name |> read!() |> Nfse.Sefin.decode_nfse()
    nfse
  end
end
