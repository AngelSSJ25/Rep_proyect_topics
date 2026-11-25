
from datetime import datetime

from src.etl.postgres_to_snowflake import main as run_etl
from src.snowflake_db import get_snowflake_connection


# =====================================================
# SMART STORE - PIPELINE PRINCIPAL
# PostgreSQL -> RAW -> STAGING -> DW -> ANALYTICS
# =====================================================

PROCEDURE_NAME = "SMART_STORE_DW.DW.SP_REFRESH_DW"

EXPECTED_RESULT = (
    "ACTUALIZACION DEL DATA WAREHOUSE COMPLETADA"
)


def refresh_data_warehouse():
    """
    Ejecuta el procedimiento almacenado de Snowflake
    que actualiza las dimensiones y tablas de hechos.
    """

    connection = None

    try:
        connection = get_snowflake_connection()

        with connection.cursor() as cursor:

            print()
            print("=" * 60)
            print("ACTUALIZANDO MODELO DIMENSIONAL")
            print("=" * 60)

            cursor.execute(
                f"CALL {PROCEDURE_NAME}()"
            )

            result = cursor.fetchone()

            if result is None:
                raise RuntimeError(
                    "Snowflake no devolvio resultado "
                    "del procedimiento."
                )

            message = str(result[0])

            if message != EXPECTED_RESULT:
                raise RuntimeError(
                    f"Resultado inesperado: {message}"
                )

            print(message)

    finally:
        if connection is not None:
            connection.close()


def main():
    start_time = datetime.now()

    print()
    print("=" * 60)
    print("SMART STORE - PIPELINE COMPLETO")
    print("=" * 60)
    print(f"Inicio: {start_time}")
    print()

    try:

        # ETAPA 1: Extraccion y carga PostgreSQL -> RAW
        print("[1/2] EJECUTANDO ETL POSTGRESQL -> SNOWFLAKE")

        run_etl()

        # ETAPA 2: Actualizar dimensiones y hechos
        print()
        print("[2/2] ACTUALIZANDO DATA WAREHOUSE")

        refresh_data_warehouse()

        end_time = datetime.now()
        duration = end_time - start_time

        print()
        print("=" * 60)
        print("PIPELINE COMPLETADO CORRECTAMENTE")
        print("=" * 60)
        print(f"Inicio: {start_time}")
        print(f"Fin: {end_time}")
        print(f"Duracion: {duration}")
        print("=" * 60)

    except Exception as error:

        print()
        print("=" * 60)
        print("ERROR DURANTE EL PIPELINE")
        print(str(error))
        print("=" * 60)

        raise SystemExit(1)


if __name__ == "__main__":
    main()
