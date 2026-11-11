# Origem dos arquivos de `priv/`

- `nfse_logo.png`: logomarca da NFS-e que a NT 008 (item 2.4.3) manda imprimir no cabeçalho do
  DANFSe, extraída do PDF do DANFSe que o Emissor Nacional gera: a imagem de 540 x 107 pixels com a
  máscara de transparência que o governo embute nele. O governo também publica a logomarca em
  <https://www.gov.br/nfse/pt-br/biblioteca/documentacao-tecnica/logos-da-nfs-e>. A logomarca é
  marca do governo federal e não está coberta pela licença MIT da biblioteca.
- `fonts/LiberationSans-Regular.ttf` e `fonts/LiberationSans-Bold.ttf`: Liberation Sans 2.1.5,
  do release em <https://github.com/liberationfonts/liberation-fonts/releases/tag/2.1.5>, sob a
  SIL Open Font License 1.1 (`fonts/LICENSE`). Tem as mesmas medidas da Arial e substitui as
  fontes da NT quando a opção `:fonts_dir` não é informada.
- `municipios.csv`: gerado por `mix nfse_danfse.gen.places` a partir da API de localidades do IBGE.
