
import json
import uuid

from datetime import date, datetime
from decimal import Decimal

from psycopg.rows import dict_row

from src.db import get_connection
from src.snowflake_db import get_snowflake_connection


# =====================================================
# SMART STORE - ETL POSTGRESQL -> SNOWFLAKE
# =====================================================

BATCH_SIZE = 150
PROCESS_NAME = "POSTGRES_TO_SNOWFLAKE"


# Tablas autorizadas y sus claves primarias.
# El orden facilita el seguimiento de las cargas.

TABLES = {
    "categorias": "categoria_id",
    "clientes": "cliente_id",
    "proveedores": "proveedor_id",
    "almacenes": "almacen_id",
    "ubicaciones": "ubicacion_id",
    "productos": "producto_id",
    "dispositivos_iot": "dispositivo_id",
    "inventarios": "inventario_id",
    "pedidos": "pedido_id",
    "detalle_pedidos": "detalle_id",
    "historial_pedidos": "historial_id",
    "reservas_inventario": "reserva_id",
    "movimientos_inventario": "movimiento_id",
}


DATE_FIELDS = (
    "actualizado_en",
    "fecha_movimiento",
    "fecha_evento",
    "fecha_reserva",
    "fecha_pedido",
    "fecha_creacion",
    "fecha_registro",
)


# =====================================================
# CONVERSION DE TIPOS A JSON
# =====================================================

def json_serializer(value):
    """
    Convierte valores especiales de PostgreSQL
    a representaciones compatibles con JSON.
    """

    if isinstance(value, (datetime, date)):
        return value.isoformat()

    if isinstance(value, Decimal):
        return str(value)

    if isinstance(value, uuid.UUID):
        return str(value)

    if isinstance(value, bytes):
        return value.hex()

    raise TypeError(
        f"Tipo no serializable: {type(value).__name__}"
    )


def get_update_timestamp(record):
    """
    Obtiene la fecha mas representativa
    de creacion o actualizacion del registro.
    """

    for field in DATE_FIELDS:
        value = record.get(field)

        if value is not None:
            if isinstance(value, (datetime, date)):
                return value.isoformat()

            return str(value)

    return None


def build_record(table, primary_key, record):
    """
    Prepara un registro para la capa RAW
    de Snowflake.
    """

    record_id = record.get(primary_key)

    if record_id is None:
        raise ValueError(
            f"Registro sin clave primaria en {table}"
        )

    return {
        "source_table": table,
        "record_id": str(record_id),
        "record_data": record,
        "source_updated_at": get_update_timestamp(
            record
        ),
    }


# =====================================================
# MERGE IDEMPOTENTE EN SNOWFLAKE
# =====================================================

MERGE_SQL = """
MERGE INTO SMART_STORE_DW.RAW.POSTGRES_RECORDS AS target

USING (
    SELECT
        f.value:source_table::VARCHAR
            AS SOURCE_TABLE,

        f.value:record_id::VARCHAR
            AS RECORD_ID,

        f.value:record_data
            AS RECORD_DATA,

        TRY_TO_TIMESTAMP_TZ(
            f.value:source_updated_at::VARCHAR
        ) AS SOURCE_UPDATED_AT

    FROM TABLE(
        FLATTEN(INPUT => PARSE_JSON(%s))
    ) AS f

) AS source

ON target.SOURCE_TABLE = source.SOURCE_TABLE
AND target.RECORD_ID = source.RECORD_ID

WHEN MATCHED AND (
    HASH(target.RECORD_DATA)
        <> HASH(source.RECORD_DATA)

    OR target.SOURCE_UPDATED_AT
        IS DISTINCT FROM source.SOURCE_UPDATED_AT
)

THEN UPDATE SET
    target.RECORD_DATA = source.RECORD_DATA,
    target.SOURCE_UPDATED_AT =
        source.SOURCE_UPDATED_AT,
    target.LOADED_AT = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN

INSERT (
    SOURCE_TABLE,
    RECORD_ID,
    RECORD_DATA,
    SOURCE_UPDATED_AT,
    LOADED_AT
)

VALUES (
    source.SOURCE_TABLE,
    source.RECORD_ID,
    source.RECORD_DATA,
    source.SOURCE_UPDATED_AT,
    CURRENT_TIMESTAMP()
)
"""


def merge_batch(snowflake_cursor, records):
    """
    Envia un lote de registros a Snowflake.

    MERGE inserta registros nuevos y actualiza
    los modificados. Los registros sin cambios
    permanecen intactos.
    """

    if not records:
        return 0

    payload = json.dumps(
        records,
        default=json_serializer,
        ensure_ascii=False,
        separators=(",", ":"),
    )

    snowflake_cursor.execute(
        MERGE_SQL,
        (payload,),
    )

    return len(records)


# =====================================================
# REGISTRO DE EJECUCIONES ETL
# =====================================================

def start_execution(cursor, execution_id):
    cursor.execute(
        """
        INSERT INTO SMART_STORE_DW.RAW.ETL_EXECUTIONS (
            EXECUTION_ID,
            PROCESS_NAME,
            STARTED_AT,
            STATUS,
            RECORDS_PROCESSED
        )
        VALUES (
            %s,
            %s,
            CURRENT_TIMESTAMP(),
            'RUNNING',
            0
        )
        """,
        (execution_id, PROCESS_NAME),
    )


def finish_execution(
    cursor,
    execution_id,
    status,
    records_processed,
    error_message=None,
):
    cursor.execute(
        """
        UPDATE SMART_STORE_DW.RAW.ETL_EXECUTIONS
        SET
            FINISHED_AT = CURRENT_TIMESTAMP(),
            STATUS = %s,
            RECORDS_PROCESSED = %s,
            ERROR_MESSAGE = %s
        WHERE EXECUTION_ID = %s
        """,
        (
            status,
            records_processed,
            error_message,
            execution_id,
        ),
    )


# =====================================================
# EXTRACCION Y TRANSFERENCIA DE TABLAS
# =====================================================

def transfer_table(
    postgres_conn,
    snowflake_cursor,
    table,
    primary_key,
):
    """
    Extrae una tabla de PostgreSQL y realiza
    cargas por lotes hacia Snowflake.
    """

    processed = 0

    # Los nombres de tabla y columna provienen
    # exclusivamente del diccionario TABLES.

    query = (
        f"SELECT * "
        f"FROM operacion.{table} "
        f"ORDER BY {primary_key}"
    )

    with postgres_conn.cursor(
        row_factory=dict_row
    ) as pg_cursor:

        pg_cursor.execute(query)

        while True:
            rows = pg_cursor.fetchmany(BATCH_SIZE)

            if not rows:
                break

            batch = [
                build_record(
                    table,
                    primary_key,
                    row,
                )
                for row in rows
            ]

            processed += merge_batch(
                snowflake_cursor,
                batch,
            )

    return processed


# =====================================================
# PROCESO PRINCIPAL
# =====================================================

def main():
    execution_id = str(uuid.uuid4())

    total_processed = 0
    table_counts = {}

    print("=" * 60)
    print("SMART STORE - ETL POSTGRESQL A SNOWFLAKE")
    print("=" * 60)

    snowflake_conn = None
    execution_started = False

    try:
        # Conexion a Snowflake

        snowflake_conn = (
            get_snowflake_connection()
        )

        # Cada MERGE confirmado permanece guardado.
        # Una ejecucion interrumpida puede repetirse.

        snowflake_conn.autocommit(True)

        with snowflake_conn.cursor() as sf_cursor:

            start_execution(
                sf_cursor,
                execution_id,
            )

            execution_started = True

            # Conexion a PostgreSQL

            with get_connection() as pg_conn:

                for table, primary_key in TABLES.items():

                    count = transfer_table(
                        pg_conn,
                        sf_cursor,
                        table,
                        primary_key,
                    )

                    table_counts[table] = count
                    total_processed += count

                    print(
                        f"{table:<25} {count:>8} registros"
                    )

            finish_execution(
                sf_cursor,
                execution_id,
                "SUCCESS",
                total_processed,
            )

            # Un solo resumen final de la carga

            sf_cursor.execute(
                """
                SELECT COUNT(*)
                FROM SMART_STORE_DW.RAW.POSTGRES_RECORDS
                """
            )

            total_snowflake = sf_cursor.fetchone()[0]

        print("=" * 60)
        print("ETL COMPLETADO CORRECTAMENTE")
        print("=" * 60)

        print(
            f"Tablas procesadas: {len(table_counts)}"
        )

        print(
            f"Registros leidos: {total_processed}"
        )

        print(
            f"Registros en Snowflake: "
            f"{total_snowflake}"
        )

        print(
            f"Execution ID: {execution_id}"
        )

        print("=" * 60)

    except Exception as error:

        if (
            snowflake_conn is not None
            and execution_started
        ):
            try:
                with snowflake_conn.cursor() as cursor:
                    finish_execution(
                        cursor,
                        execution_id,
                        "FAILED",
                        total_processed,
                        str(error)[:1800],
                    )
            except Exception:
                pass

        print("=" * 60)
        print("ERROR DURANTE EL ETL")
        print(str(error))
        print("=" * 60)

        raise SystemExit(1)

    finally:
        if snowflake_conn is not None:
            snowflake_conn.close()


if __name__ == "__main__":
    main()
