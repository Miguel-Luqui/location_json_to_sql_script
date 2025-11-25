-- ============================================================
-- 1) CRIAÇÃO CONDICIONAL DO BANCO
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sbl_database') THEN
        EXECUTE format(
            'CREATE DATABASE %I WITH OWNER %I ENCODING ''UTF8'' LC_COLLATE ''en_US.utf8'' LC_CTYPE ''en_US.utf8'' TEMPLATE template0;',
            'sbl_database',
            current_user
        );
    END IF;
END
$$;

-- Se estiver usando psql interativo, descomente:
\connect sbl_database

-- ============================================================
-- 2) EXTENSÕES E SCHEMA
-- ============================================================
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE SCHEMA IF NOT EXISTS sbl_schema;
    SET search_path TO sbl_schema;
END
$$;

-- ============================================================
-- 3) FUNÇÃO ULID (corrigida, estável)
-- ============================================================
CREATE OR REPLACE FUNCTION sbl_schema.generate_ulid() RETURNS TEXT AS $$
DECLARE
    timestamp_ms BIGINT;
    random_bytes BYTEA;
    -- Caracteres Crockford's Base32 (sem I, L, O, U para evitar confusão)
    encoding TEXT := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    timestamp_part TEXT := '';
    random_part TEXT := '';
    temp_val BIGINT;
    byte_array BIGINT[];
    combined_val BIGINT;
    i INT;
BEGIN
    -- Obtém timestamp em milissegundos desde Unix Epoch
    timestamp_ms := FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT;
    
    -- Gera 10 bytes aleatórios (80 bits)
    random_bytes := gen_random_bytes(10);
    
    -- === PARTE 1: Codifica timestamp em 10 caracteres Base32 ===
    temp_val := timestamp_ms;
    FOR i IN 1..10 LOOP
        timestamp_part := substring(encoding FROM ((temp_val % 32)::INT + 1) FOR 1) || timestamp_part;
        temp_val := temp_val / 32;
    END LOOP;
    
    -- === PARTE 2: Codifica 80 bits aleatórios em 16 caracteres Base32 ===
    -- Converte bytes em array de valores
    byte_array := ARRAY[
        get_byte(random_bytes, 0)::BIGINT,
        get_byte(random_bytes, 1)::BIGINT,
        get_byte(random_bytes, 2)::BIGINT,
        get_byte(random_bytes, 3)::BIGINT,
        get_byte(random_bytes, 4)::BIGINT,
        get_byte(random_bytes, 5)::BIGINT,
        get_byte(random_bytes, 6)::BIGINT,
        get_byte(random_bytes, 7)::BIGINT,
        get_byte(random_bytes, 8)::BIGINT,
        get_byte(random_bytes, 9)::BIGINT
    ];
    
    -- Combina bytes e extrai valores Base32
    -- Grupo 1: 5 bytes = 40 bits = 8 caracteres
    combined_val := (byte_array[1] << 32) | (byte_array[2] << 24) | (byte_array[3] << 16) | (byte_array[4] << 8) | byte_array[5];
    FOR i IN 1..8 LOOP
        random_part := substring(encoding FROM ((combined_val % 32)::INT + 1) FOR 1) || random_part;
        combined_val := combined_val / 32;
    END LOOP;
    
    -- Grupo 2: 5 bytes = 40 bits = 8 caracteres
    combined_val := (byte_array[6] << 32) | (byte_array[7] << 24) | (byte_array[8] << 16) | (byte_array[9] << 8) | byte_array[10];
    FOR i IN 1..8 LOOP
        random_part := substring(encoding FROM ((combined_val % 32)::INT + 1) FOR 1) || random_part;
        combined_val := combined_val / 32;
    END LOOP;
    
    -- Retorna timestamp (10 chars) + random (16 chars) = 26 caracteres
    RETURN timestamp_part || random_part;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ============================================================
-- 4) FUNÇÃO DE AUDITORIA (updated_at)
-- ============================================================
CREATE OR REPLACE FUNCTION sbl_schema.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 5) TABELAS
-- ============================================================

CREATE TABLE IF NOT EXISTS sbl_schema."Region" (
    "id" CHAR(26) PRIMARY KEY,
    "name" VARCHAR(150),
    "translations" TEXT,
    "id_internal" INTEGER,
    "flag" INTEGER DEFAULT 1,
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sbl_schema."SubRegion" (
    "id" CHAR(26) PRIMARY KEY,
    "id_region" CHAR(26) REFERENCES sbl_schema."Region"("id"),
    "name" VARCHAR(150),
    "translations" TEXT,
    "id_internal" INTEGER,
    "flag" INTEGER DEFAULT 1,
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sbl_schema."Country" (
    "id" CHAR(26) PRIMARY KEY,
    "id_subregion" CHAR(26) REFERENCES sbl_schema."SubRegion"("id"),
    "name" VARCHAR(150),
    "iso_2" CHAR(2),
    "iso_3" CHAR(3),
    "numeric_code" VARCHAR(15),
    "phone_code" VARCHAR(15),
    "capital" VARCHAR(100),
    "currency" CHAR(3),
    "currency_name" VARCHAR(60),
    "currency_symbol" VARCHAR(20),
    "tld" CHAR(3),
    "native" VARCHAR(60),
    "population" INTEGER,
    "gdp" INTEGER,
    "region" VARCHAR(255),
    "subregion" VARCHAR(50),
    "nationality" VARCHAR(50),
    "timezones" TEXT,
    "translations" TEXT,
    "latitude" NUMERIC(10,8),
    "longitude" NUMERIC(11,8),
    "emoji" CHAR(2),
    "emoji_u" VARCHAR(20),
    "id_internal" INTEGER,
    "flag" INTEGER DEFAULT 1,
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sbl_schema."State" (
    "id" CHAR(26) PRIMARY KEY,
    "id_country" CHAR(26) REFERENCES sbl_schema."Country"("id"),
    "name" VARCHAR(150),
    "country_code" CHAR(2),
    "fips_code" VARCHAR(50),
    "iso_2" VARCHAR(10),
    "iso_3166_2" VARCHAR(10),
    "type" VARCHAR(60),
    "level" INTEGER,
    "native" VARCHAR(100),
    "latitude" NUMERIC(10,8),
    "longitude" NUMERIC(11,8),
    "timezone" VARCHAR(50),
    "translations" TEXT,
    "id_internal" INTEGER,
    "flag" INTEGER DEFAULT 1,
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sbl_schema."City" (
    "id" CHAR(26) PRIMARY KEY,
    "id_state" CHAR(26) REFERENCES sbl_schema."State"("id"),
    "id_country" CHAR(26) REFERENCES sbl_schema."Country"("id"),
    "name" VARCHAR(150),
    "latitude" NUMERIC(10,8),
    "longitude" NUMERIC(11,8),
    "timezone" TEXT,
    "translations" TEXT,
    "id_internal" INTEGER,
    "flag" INTEGER DEFAULT 1,
    "created_at" TIMESTAMPTZ DEFAULT now(),
    "updated_at" TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 6) TRIGGERS AUTOMÁTICAS updated_at
-- ============================================================
DO $$
DECLARE
    r RECORD;
    trig_name TEXT;
    relreg TEXT;
BEGIN
    FOR r IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE table_schema = 'sbl_schema'
          AND column_name = 'updated_at'
    LOOP
        trig_name := format('trg_set_updated_at_%I', r.table_name);
        relreg := format('sbl_schema."%s"', r.table_name);

        IF NOT EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = trig_name AND tgrelid = relreg::regclass
        ) THEN
            EXECUTE format(
                'CREATE TRIGGER %I
                 BEFORE UPDATE ON %s
                 FOR EACH ROW
                 EXECUTE FUNCTION sbl_schema.set_updated_at();',
                trig_name, relreg
            );
        END IF;
    END LOOP;
END$$;
