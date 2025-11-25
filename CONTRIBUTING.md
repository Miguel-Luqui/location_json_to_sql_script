# Lista de JSONs necessários

- `cities.json`
- `countries.json`
- `regions.json`
- `states.json`
- `subregions.json`

---

# Fonte dos arquivos JSON

Os arquivos podem ser baixados em:

https://github.com/dr5hn/countries-states-cities-database/tree/master/json

---

# Como usar

1. Coloque os arquivos JSON de localização na pasta `input_jsons/`.
2. Execute o script Python no terminal:

    ```bash
    python location_seeder_generator.py
    ```

3. Por fim, o script sql será gerado na pasta "output_sql".

---

# Comando bash para rodar o arquivo sql no banco:

    ```bash
    $ docker exec -i <nome_ou_id_do_container> psql -U <usuario> -d <nome_do_banco> < <caminho_do_arquivo_sql_no_host>
    ```