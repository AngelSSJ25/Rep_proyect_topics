
import re
from pathlib import Path


# =====================================================
# SMART STORE
# GENERADOR DEL PROCEDIMIENTO DE ACTUALIZACION DW
# =====================================================

BASE_DIR = Path(__file__).resolve().parents[2]

SQL_DIR = BASE_DIR / "database" / "snowflake"

DIMENSIONS_FILE = SQL_DIR / "07_refresh_dimensions.sql"
FACTS_FILE = SQL_DIR / "08_refresh_facts.sql"

OUTPUT_FILE = SQL_DIR / "09_create_refresh_procedure.sql"


def extract_merges(file_path, expected_count):
    """
    Extrae las instrucciones MERGE de un archivo SQL
    previamente utilizado en Snowflake.
    """

    if not file_path.is_file():
        raise FileNotFoundError(
            f"No se encontro el archivo: {file_path}"
        )

    content = file_path.read_text(
        encoding="utf-8-sig"
    )

    statements = re.findall(
        r"\bMERGE\s+INTO\b[\s\S]*?;",
        content,
        flags=re.IGNORECASE
    )

    if len(statements) != expected_count:
        raise ValueError(
            f"Se esperaban {expected_count} MERGE en "
            f"{file_path.name}, pero se encontraron "
            f"{len(statements)}."
        )

    return [
        statement.strip()
        for statement in statements
    ]


def generate_procedure():
    print("=" * 55)
    print("SMART STORE - GENERACION DE PROCEDIMIENTO DW")
    print("=" * 55)

    # Extraer los MERGE existentes
    dimension_merges = extract_merges(
        DIMENSIONS_FILE,
        expected_count=5
    )

    fact_merges = extract_merges(
        FACTS_FILE,
        expected_count=3
    )

    # Las dimensiones siempre se actualizan primero
    all_merges = dimension_merges + fact_merges

    statements = "\n\n".join(
        "    " + statement.replace("\n", "\n    ")
        for statement in all_merges
    )

    sql = f"""-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 09 - PROCEDIMIENTO DE ACTUALIZACION DW
-- Archivo generado automaticamente desde 07 y 08
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ETL;
USE DATABASE SMART_STORE_DW;
USE SCHEMA DW;

ALTER SESSION SET ERROR_ON_NONDETERMINISTIC_MERGE = TRUE;

CREATE OR REPLACE PROCEDURE
    SMART_STORE_DW.DW.SP_REFRESH_DW()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

{statements}

    RETURN 'ACTUALIZACION DEL DATA WAREHOUSE COMPLETADA';

END;
$$;

-- Ejecutar el procedimiento una vez
CALL SMART_STORE_DW.DW.SP_REFRESH_DW();
"""

    OUTPUT_FILE.write_text(
        sql,
        encoding="utf-8"
    )

    print(
        f"MERGE de dimensiones: {len(dimension_merges)}"
    )

    print(
        f"MERGE de hechos: {len(fact_merges)}"
    )

    print(
        f"Total de operaciones: {len(all_merges)}"
    )

    print("=" * 55)
    print("PROCEDIMIENTO SQL GENERADO CORRECTAMENTE")
    print(f"Archivo: {OUTPUT_FILE}")
    print("=" * 55)


if __name__ == "__main__":
    generate_procedure()
