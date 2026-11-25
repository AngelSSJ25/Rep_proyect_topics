
import json
from pathlib import Path

from src.snowflake_db import get_snowflake_connection


# =====================================================
# SMART STORE
# SINCRONIZACION DE EVENTOS IOT CORREGIDOS
# =====================================================

BASE_DIR = Path(__file__).resolve().parents[2]

JSON_FILE = BASE_DIR / "data" / "raw" / "iot_events.jsonl"

EXPECTED_EVENTS = 6109

STAGE = (
    "SMART_STORE_DW.RAW.STG_IOT_EVENTS"
)

STAGE_FOLDER = "historical_fix_20261122"

STAGE_PATH = f"@{STAGE}/{STAGE_FOLDER}/"

RAW_TABLE = "SMART_STORE_DW.RAW.IOT_EVENTS"

TEMP_TABLE = "TEMP_IOT_HISTORICAL_FIX"


def validate_local_file():
    """
    Valida la cantidad e identificadores del JSON
    antes de comenzar la carga a Snowflake.
    """

    if not JSON_FILE.is_file():
        raise FileNotFoundError(
            f"No existe el archivo: {JSON_FILE}"
        )

    event_ids = set()
    movement_ids = set()
    total = 0

    with JSON_FILE.open(
        "r", encoding="utf-8"
    ) as file:

        for line_number, line in enumerate(file, 1):

            if not line.strip():
                continue

            event = json.loads(line)

            event_id = event.get("event_id")
            movement_id = event.get("movement_id")

            if not event_id or movement_id is None:
                raise ValueError(
                    f"Evento incompleto en linea {line_number}"
                )

            if event_id in event_ids:
                raise ValueError(
                    f"Evento duplicado: {event_id}"
                )

            if movement_id in movement_ids:
                raise ValueError(
                    f"Movimiento duplicado: {movement_id}"
                )

            event_ids.add(event_id)
            movement_ids.add(movement_id)

            total += 1

    if total != EXPECTED_EVENTS:
        raise ValueError(
            f"Se esperaban {EXPECTED_EVENTS} eventos, "
            f"pero se encontraron {total}"
        )

    return total


def upload_json(cursor):
    """
    Sube el archivo corregido al stage de Snowflake,
    dentro de una carpeta independiente.
    """

    file_uri = "file://" + JSON_FILE.resolve().as_posix()

    cursor.execute(
        f"""
        PUT '{file_uri}'
        {STAGE_PATH}
        AUTO_COMPRESS = FALSE
        OVERWRITE = TRUE
        """
    )


def load_temporary_table(cursor):
    """
    Carga el JSON en una tabla temporal.
    No modifica todavia la tabla RAW original.
    """

    cursor.execute(f"""
        CREATE OR REPLACE TEMPORARY TABLE
        {TEMP_TABLE} (
            EVENT_DATA VARIANT,
            SOURCE_FILE VARCHAR(500)
        )
    """)

    cursor.execute(f"""
        COPY INTO {TEMP_TABLE} (
            EVENT_DATA,
            SOURCE_FILE
        )
        FROM (
            SELECT
                T.$1,
                METADATA$FILENAME
            FROM {STAGE_PATH}
                (
                    FILE_FORMAT =>
                    'SMART_STORE_DW.RAW.FF_IOT_JSON'
                ) T
        )
        FILES = ('iot_events.jsonl')
        ON_ERROR = ABORT_STATEMENT
        FORCE = TRUE
    """)


def validate_snowflake_data(cursor):
    """
    Comprueba que los eventos temporales coincidan
    con los existentes antes de actualizarlos.
    """

    cursor.execute(f"""
        SELECT
            COUNT(*),
            COUNT(DISTINCT EVENT_DATA:event_id::STRING),
            COUNT(DISTINCT EVENT_DATA:movement_id::STRING)
        FROM {TEMP_TABLE}
    """)

    total, unique_events, unique_movements = cursor.fetchone()

    if (
        total != EXPECTED_EVENTS
        or unique_events != EXPECTED_EVENTS
        or unique_movements != EXPECTED_EVENTS
    ):
        raise RuntimeError(
            "La carga temporal contiene registros "
            "incompletos o duplicados."
        )

    cursor.execute(f"""
        SELECT
            COUNT(*),
            COUNT(DISTINCT EVENT_DATA:event_id::STRING)
        FROM {RAW_TABLE}
    """)

    raw_total, raw_unique = cursor.fetchone()

    if raw_total != EXPECTED_EVENTS or raw_unique != EXPECTED_EVENTS:
        raise RuntimeError(
            "La tabla RAW no coincide con los "
            "6109 eventos originales."
        )

    cursor.execute(f"""
        SELECT COUNT(*)
        FROM {TEMP_TABLE} S
        INNER JOIN {RAW_TABLE} T
            ON S.EVENT_DATA:event_id::STRING =
               T.EVENT_DATA:event_id::STRING
    """)

    matches = cursor.fetchone()[0]

    if matches != EXPECTED_EVENTS:
        raise RuntimeError(
            "Los identificadores temporales no "
            "coinciden con los eventos originales."
        )


def update_events(cursor):
    """
    Actualiza exclusivamente los eventos modificados,
    identificandolos por su EVENT_ID.
    """

    cursor.execute(f"""
        MERGE INTO {RAW_TABLE} T

        USING {TEMP_TABLE} S

        ON T.EVENT_DATA:event_id::STRING =
           S.EVENT_DATA:event_id::STRING

        WHEN MATCHED AND
            HASH(T.EVENT_DATA) <> HASH(S.EVENT_DATA)

        THEN UPDATE SET
            T.EVENT_DATA = S.EVENT_DATA,
            T.SOURCE_FILE = S.SOURCE_FILE,
            T.LOAD_TIMESTAMP = CURRENT_TIMESTAMP()
    """)

    result = cursor.fetchone()

    if result is None:
        raise RuntimeError(
            "Snowflake no devolvio el resultado del MERGE."
        )

    return result


def main():
    print("=" * 60)
    print("SMART STORE - SINCRONIZACION IOT")
    print("=" * 60)

    connection = None

    try:
        total = validate_local_file()

        print(f"Archivo JSON: {total} eventos")
        print("Archivo local validado.")

        connection = get_snowflake_connection()
        connection.autocommit(True)

        with connection.cursor() as cursor:

            print("Subiendo archivo corregido...")
            upload_json(cursor)

            print("Cargando eventos temporalmente...")
            load_temporary_table(cursor)

            print("Comprobando correspondencia de eventos...")
            validate_snowflake_data(cursor)

            print("Actualizando eventos modificados...")

            connection.autocommit(False)

            try:
                result = update_events(cursor)
                connection.commit()

            except Exception:
                connection.rollback()
                raise

        print("=" * 60)
        print("SINCRONIZACION IOT COMPLETADA")
        print("=" * 60)
        print(f"Eventos conservados: {total}")
        print(f"Resultado MERGE: {result}")
        print("No se insertaron eventos duplicados.")
        print("=" * 60)

    except Exception as error:
        print("=" * 60)
        print("ERROR DURANTE LA SINCRONIZACION")
        print(str(error))
        print("=" * 60)
        raise SystemExit(1)

    finally:
        if connection is not None:
            connection.close()


if __name__ == "__main__":
    main()
