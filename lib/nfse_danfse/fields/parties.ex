defmodule NfseDanfse.Fields.Parties do
  @moduledoc false

  alias Nfse.Schema.V1_01.TCRTCInfoDest
  alias NfseDanfse.Descriptions
  alias NfseDanfse.Format
  alias NfseDanfse.Places

  @without_address %{municipality: "-", ibge_cep: "-", address: "-"}

  @doc """
  Campos do prestador, lidos do `prest` da DPS e completados pelo `emit` quando o próprio
  prestador emitiu a nota.
  """
  @spec provider(struct()) :: map()
  def provider(%{dps: %{inf_dps: inf_dps}, emit: emitter}) do
    regime = inf_dps.prest.reg_trib

    inf_dps.prest
    |> fill_in_from_emitter(inf_dps.tp_emit, emitter)
    |> party()
    |> Map.merge(%{
      simples_nacional: Descriptions.text(:op_simp_nac, regime.op_simp_nac, 37),
      simples_regime: Descriptions.text(:reg_ap_trib_sn, regime.reg_ap_trib_sn, 77)
    })
  end

  @doc """
  Campos do tomador, do destinatário ou do intermediário, ou `nil` quando a nota não os tem.
  """
  @spec party(struct() | nil) :: map() | nil
  def party(nil), do: nil

  # O leiaute do destinatário não tem inscrição municipal, e o DANFSe não reserva o campo para ele.
  def party(%TCRTCInfoDest{} = recipient), do: identity_and_address(recipient)

  def party(person) do
    person
    |> identity_and_address()
    |> Map.put(:municipal_registration, Format.text(person.im))
  end

  # Só na nota emitida pelo prestador o `emit` é ele mesmo. Emitida pelo tomador ou pelo
  # intermediário, o `emit` é quem emitiu, e os dados dele nunca são os do prestador.
  defp fill_in_from_emitter(provider, "1", emitter) do
    %{
      provider
      | im: provider.im || emitter.im,
        x_nome: provider.x_nome || emitter.x_nome,
        fone: provider.fone || emitter.fone,
        email: provider.email || emitter.email,
        end: provider.end || emitter.ender_nac
    }
  end

  defp fill_in_from_emitter(provider, _tp_emit, _emitter), do: provider

  defp identity_and_address(person) do
    Map.merge(
      %{
        document: document(person),
        phone: Format.text(person.fone),
        name: Format.text(person.x_nome, 77),
        email: Format.text(person.email, 77)
      },
      location(person.end)
    )
  end

  defp document(%{cnpj: cnpj}) when is_binary(cnpj), do: Format.cnpj(cnpj)
  defp document(%{cpf: cpf}) when is_binary(cpf), do: Format.cpf(cpf)
  defp document(%{nif: nif}) when is_binary(nif), do: Format.text(nif)
  defp document(_person_without_document), do: "-"

  defp location(nil), do: @without_address

  defp location(address) do
    locality = locality(address)

    %{
      municipality: municipality(locality),
      ibge_cep: ibge_cep(locality),
      address: street_address(address)
    }
  end

  # O endereço da DPS guarda município e CEP em `endNac` ou `endExt`; o do `emit`, no próprio grupo.
  defp locality(%{end_ext: %{} = foreign}), do: foreign
  defp locality(%{end_nac: %{} = national}), do: national
  defp locality(emitter_address), do: emitter_address

  # O campo tem 37 caracteres no DANFSe, e o leiaute aceita cidade e região bem mais longas.
  defp municipality(%{x_cidade: city, x_est_prov_reg: region}),
    do: Format.text("#{city} / #{region}", 34)

  defp municipality(%{c_mun: code}) do
    case Places.municipality(code) do
      {:ok, %{name: name, uf: state}} -> "#{name} / #{state}"
      :error -> code
    end
  end

  defp ibge_cep(%{c_end_post: postal_code}), do: Format.text("- / #{postal_code}")
  defp ibge_cep(%{c_mun: code, cep: cep}), do: "#{Format.ibge_code(code)} / #{Format.cep(cep)}"

  defp street_address(address) do
    [address.x_lgr, address.nro, address.x_cpl, address.x_bairro]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
    |> Format.text(77)
  end
end
