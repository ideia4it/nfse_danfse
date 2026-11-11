# Changelog

## 0.1.0

Primeira versão.

- `NfseDanfse.render/2` gera o PDF do DANFSe v2.0 em uma página, a partir do XML da NFS-e Nacional (leiautes 1.00 e 1.01), seguindo a NT 008 v1.01 e, onde ela diverge, o PDF do portal nacional.
- Opção `situation:` (`:cancelled` ou `:replaced`) para a marca d'água.
- Opção `fonts_dir:` para usar Arial, Arial Bold e Microsoft Sans Serif; sem ela, a Liberation Sans embutida.
- Erros em `%NfseDanfse.Error{}`, com `kind` `:invalid_xml`, `:invalid_option` ou `:render`.
