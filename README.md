# Location Seeder Generator

Script Python que transforma arquivos JSON de localização (cidades, estados, regiões, países, sub-regiões) em scripts SQL para popular bancos de dados PostgreSQL.

---

## Funcionalidade

- Converte arquivos JSON de localização em comandos `INSERT` SQL.
- Gera o arquivo SQL pronto para ser executado no banco.
- Facilita popular bancos PostgreSQL com dados de localização.

---

## Como usar

Para instruções detalhadas de uso, incluindo como baixar os JSONs, executar o script e rodar o SQL no banco, consulte o arquivo [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Requisitos

- JSONs de localização (cities.json, countries.json, regions.json, states.json, subregions.json)

---

## Observações

- Certifique-se de colocar os arquivos JSON na pasta `input_jsons/`.
- O script irá gerar automaticamente o SQL correspondente na pasta `output_sql/`.
