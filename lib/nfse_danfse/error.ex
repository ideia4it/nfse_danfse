defmodule NfseDanfse.Error do
  @moduledoc """
  Erro devolvido pela biblioteca.

  `kind` diz o que falhou: `:invalid_xml` (o XML não é uma NFS-e legível), `:invalid_option`
  (opção de renderização inválida) ou `:render` (a composição do PDF falhou). `cause` guarda o
  erro original quando existe.
  """

  @type kind :: :invalid_xml | :invalid_option | :render

  @type t :: %__MODULE__{kind: kind(), message: String.t(), cause: term()}

  defexception [:kind, :message, :cause]
end
