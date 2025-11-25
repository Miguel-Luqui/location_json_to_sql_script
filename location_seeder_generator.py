import os
import json

# ---------------------------------------------------------------------
#  STRING SANITIZATION HELPERS
# ---------------------------------------------------------------------

def escape_sql_string(text):
    """Ensures text is UTF-8 safe and escapes single quotes for SQL."""
    if text is None:
        return ""
    if not isinstance(text, str):
        text = str(text)
    # Ensure valid UTF-8 (replace invalid chars)
    text = text.encode("utf-8", errors="replace").decode("utf-8")
    # Escape single quotes for SQL
    return text.replace("'", "''")


def sanitize_json(obj):
    """Recursively sanitizes all strings inside JSON dicts/lists."""
    if isinstance(obj, dict):
        return {k: sanitize_json(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sanitize_json(v) for v in obj]
    elif isinstance(obj, str):
        return escape_sql_string(obj)
    return obj


def dump_json_sql_safe(obj):
    """Dumps JSON and escapes it for SQL usage."""
    dumped = json.dumps(obj, ensure_ascii=False)
    return escape_sql_string(dumped)


# ---------------------------------------------------------------------
#  INSERT GENERATORS
# ---------------------------------------------------------------------

def generate_insert_region(region_data):
    region_data = sanitize_json(region_data)
    translations = dump_json_sql_safe(region_data['translations'])
    name = escape_sql_string(region_data['name'])

    return f"""
INSERT INTO "Region" ("id", "name", "translations", "id_internal")
VALUES (sbl_schema.generate_ulid(), '{name}', '{translations}', {region_data['id']});
"""


def generate_insert_subregion(subregion_data):
    subregion_data = sanitize_json(subregion_data)
    translations = dump_json_sql_safe(subregion_data['translations'])
    name = escape_sql_string(subregion_data['name'])

    return f"""
INSERT INTO "SubRegion" ("id", "id_region", "name", "translations", "id_internal")
VALUES (
    sbl_schema.generate_ulid(),
    (SELECT id FROM "Region" WHERE id_internal = {subregion_data['region_id']}),
    '{name}',
    '{translations}',
    {subregion_data['id']}
);
"""


def generate_insert_country(country_data):
    country_data = sanitize_json(country_data)
    translations = dump_json_sql_safe(country_data['translations'])
    timezones = dump_json_sql_safe(country_data['timezones'])
    gdp_value = country_data['gdp'] if country_data['gdp'] is not None else 'NULL'

    name = escape_sql_string(country_data['name'])
    iso2 = escape_sql_string(country_data['iso2'])
    iso3 = escape_sql_string(country_data['iso3'])
    numeric_code = escape_sql_string(country_data['numeric_code'])
    phonecode = escape_sql_string(country_data['phonecode'])
    capital = escape_sql_string(country_data['capital'])
    currency = escape_sql_string(country_data['currency'])
    currency_name = escape_sql_string(country_data['currency_name'])
    currency_symbol = escape_sql_string(country_data['currency_symbol'])
    tld = escape_sql_string(country_data['tld'])
    native = escape_sql_string(country_data['native'])
    region = escape_sql_string(country_data['region'])
    subregion = escape_sql_string(country_data['subregion'])
    nationality = escape_sql_string(country_data['nationality'])
    emoji = escape_sql_string(country_data['emoji'])
    emoji_u = escape_sql_string(country_data['emojiU'])

    return f"""
INSERT INTO "Country" (
    "id", "id_subregion", "name", "iso_2", "iso_3", "numeric_code", "phone_code", "capital",
    "currency", "currency_name", "currency_symbol", "tld", "native", "population", "gdp",
    "region", "subregion", "nationality", "timezones", "translations", "latitude", "longitude",
    "emoji", "emoji_u", "id_internal"
)
VALUES (
    sbl_schema.generate_ulid(),
    (SELECT id FROM "SubRegion" WHERE id_internal = {country_data['subregion_id']}),
    '{name}', '{iso2}', '{iso3}', '{numeric_code}', '{phonecode}', '{capital}',
    '{currency}', '{currency_name}', '{currency_symbol}', '{tld}', '{native}',
    {country_data['population']}, {gdp_value},
    '{region}', '{subregion}', '{nationality}',
    '{timezones}', '{translations}',
    {country_data['latitude']}, {country_data['longitude']},
    '{emoji}', '{emoji_u}', {country_data['id']}
);
"""


def generate_insert_state(state_data):
    state_data = sanitize_json(state_data)
    translations = dump_json_sql_safe(state_data['translations'])
    timezone = dump_json_sql_safe(state_data['timezone'])

    name = escape_sql_string(state_data['name'])
    country_code = escape_sql_string(state_data['country_code'])
    fips_code = escape_sql_string(state_data['fips_code'])
    iso2 = escape_sql_string(state_data['iso2'])
    iso3166_2 = escape_sql_string(state_data['iso3166_2'])
    type_ = escape_sql_string(state_data['type'])
    native = escape_sql_string(state_data['native'])
    level_value = state_data['level'] if state_data['level'] is not None else 'NULL'

    return f"""
INSERT INTO "State" (
    "id", "id_country", "name", "country_code", "fips_code", "iso_2", "iso_3166_2", "type",
    "level", "native", "latitude", "longitude", "timezone", "translations", "id_internal"
)
VALUES (
    sbl_schema.generate_ulid(),
    (SELECT id FROM "Country" WHERE id_internal = {state_data['country_id']}),
    '{name}', '{country_code}', '{fips_code}', '{iso2}', '{iso3166_2}',
    '{type_}', {level_value}, '{native}',
    {state_data['latitude']}, {state_data['longitude']},
    '{timezone}', '{translations}', {state_data['id']}
);
"""


def generate_insert_city(city_data):
    city_data = sanitize_json(city_data)
    translations = dump_json_sql_safe(city_data['translations'])
    timezone = dump_json_sql_safe(city_data['timezone'])
    name = escape_sql_string(city_data['name'])

    return f"""
INSERT INTO "City" (
    "id", "id_state", "id_country", "name", "latitude", "longitude", "timezone", "translations", "id_internal"
)
VALUES (
    sbl_schema.generate_ulid(),
    (SELECT id FROM "State" WHERE id_internal = {city_data['state_id']}),
    (SELECT id FROM "Country" WHERE id_internal = {city_data['country_id']}),
    '{name}', {city_data['latitude']}, {city_data['longitude']},
    '{timezone}', '{translations}', {city_data['id']}
);
"""


# ---------------------------------------------------------------------
#  MAIN JSON → SQL PROCESSING
# ---------------------------------------------------------------------

def generate_sql_from_json_files(json_files):
    sql_commands = []

    mapping = [
        ('regions', generate_insert_region),
        ('subregions', generate_insert_subregion),
        ('countries', generate_insert_country),
        ('states', generate_insert_state),
        ('cities', generate_insert_city),
    ]

    for key, func in mapping:
        with open(json_files[key], 'r', encoding='utf-8', errors='replace') as f:
            items = json.load(f)
            for item in items:
                sql_commands.append(func(item))

    return "\n".join(sql_commands)


def process_multiple_jsons_to_sql(json_files, output_file):
    sql = generate_sql_from_json_files(json_files)

    # Adiciona cabeçalho de conexão e search_path
    header = "-- Se estiver usando psql interativo, descomente:\n\\connect sbl_database\n\nSET search_path TO sbl_schema, public;\n\n"
    sql = header + sql

    with open(output_file, 'w', encoding='utf-8', errors='replace') as f:
        f.write(sql)
    print(f"[OK] SQL generated safely and saved in {output_file}")


# ---------------------------------------------------------------------
#  EXECUTION
# ---------------------------------------------------------------------

if __name__ == "__main__":
    # Pasta onde estão os JSONs
    source_folder = "input_jsons"
    output_folder = "output_sql"
    os.makedirs(output_folder, exist_ok=True)

    json_files = {
        "regions": os.path.join(source_folder, "regions.json"),
        "subregions": os.path.join(source_folder, "subregions.json"),
        "countries": os.path.join(source_folder, "countries.json"),
        "states": os.path.join(source_folder, "states.json"),
        "cities": os.path.join(source_folder, "cities.json")
    }

    output_file = os.path.join(output_folder, "locations_seeder.sql")
    process_multiple_jsons_to_sql(json_files, output_file)
