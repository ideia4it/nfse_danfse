defmodule NfseDanfse.Places do
  @moduledoc false

  # Gerado por `mix nfse_danfse.gen.places` a partir da API do IBGE; não editar à mão.
  @csv_path Path.expand("../../priv/municipios.csv", __DIR__)
  @external_resource @csv_path

  @municipalities @csv_path
                  |> File.stream!()
                  |> Stream.drop(1)
                  |> Map.new(fn line ->
                    [code, name, uf] = line |> String.trim_trailing() |> String.split(";")
                    {code, %{name: name, uf: uf}}
                  end)

  @doc """
  Devolve o nome e a UF do município de código IBGE `code`, ou `:error` se não existir.

      iex> NfseDanfse.Places.municipality("2927408")
      {:ok, %{name: "Salvador", uf: "BA"}}
  """
  @spec municipality(String.t()) :: {:ok, %{name: String.t(), uf: String.t()}} | :error
  def municipality(code), do: Map.fetch(@municipalities, code)

  @doc """
  Devolve a UF do município de código IBGE `code`, ou `nil` se o código faltar ou não existir.
  """
  @spec uf(String.t() | nil) :: String.t() | nil
  def uf(nil), do: nil

  def uf(code) do
    case municipality(code) do
      {:ok, %{uf: uf}} -> uf
      :error -> nil
    end
  end
end
