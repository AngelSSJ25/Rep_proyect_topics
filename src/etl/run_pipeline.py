import argparse
from datetime import datetime

from src.etl.postgres_to_snowflake import main as run_etl
from src.snowflake_db import get_snowflake_connection


# =====================================================
# SMART STORE - PIPELINE CON BARRERA DE CALIDAD
# PostgreSQL -> RAW -> STAGING -> DW -> ANALYTICS
# =====================================================

PROCEDURE_NAME = "SMART_STORE_DW.DW.SP_REFRESH_DW"
EXPECTED_RESULT = "ACTUALIZACION DEL DATA WAREHOUSE COMPLETADA"

# Estas validaciones se ejecutan DESPUES de cargar RAW y ANTES
# de actualizar el Data Warehouse. No alteran las tablas.
PRE_REFRESH_SQL = """
SELECT '01' AS CODIGO, 'RAW sin claves o datos', COUNT(*) AS INCIDENCIAS
FROM SMART_STORE_DW.RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE IS NULL
   OR TRIM(SOURCE_TABLE) = ''
   OR RECORD_ID IS NULL
   OR TRIM(RECORD_ID) = ''
   OR RECORD_DATA IS NULL

UNION ALL
SELECT '02', 'Claves repetidas en RAW', COUNT(*)
FROM (
    SELECT SOURCE_TABLE, RECORD_ID
    FROM SMART_STORE_DW.RAW.POSTGRES_RECORDS
    GROUP BY SOURCE_TABLE, RECORD_ID
    HAVING COUNT(*) > 1
)

UNION ALL
SELECT '03', 'Pedidos con datos esenciales invalidos', COUNT(*)
FROM SMART_STORE_DW.STAGING.V_PEDIDOS
WHERE PEDIDO_ID IS NULL
   OR CLIENTE_ID IS NULL
   OR FECHA_PEDIDO IS NULL

UNION ALL
SELECT '04', 'Detalles de pedido invalidos', COUNT(*)
FROM SMART_STORE_DW.STAGING.V_DETALLE_PEDIDOS
WHERE DETALLE_ID IS NULL
   OR PEDIDO_ID IS NULL
   OR PRODUCTO_ID IS NULL
   OR CANTIDAD IS NULL OR CANTIDAD <= 0
   OR PRECIO_UNITARIO IS NULL OR PRECIO_UNITARIO < 0
   OR SUBTOTAL IS NULL OR SUBTOTAL < 0

UNION ALL
SELECT '05', 'Detalles sin pedido o producto', COUNT(*)
FROM SMART_STORE_DW.STAGING.V_DETALLE_PEDIDOS D
LEFT JOIN SMART_STORE_DW.STAGING.V_PEDIDOS P
    ON D.PEDIDO_ID = P.PEDIDO_ID
LEFT JOIN SMART_STORE_DW.STAGING.V_PRODUCTOS PR
    ON D.PRODUCTO_ID = PR.PRODUCTO_ID
WHERE P.PEDIDO_ID IS NULL OR PR.PRODUCTO_ID IS NULL

UNION ALL
SELECT '06', 'Inventarios incoherentes', COUNT(*)
FROM SMART_STORE_DW.STAGING.V_INVENTARIOS
WHERE INVENTARIO_ID IS NULL
   OR STOCK_FISICO IS NULL OR STOCK_FISICO < 0
   OR STOCK_RESERVADO IS NULL OR STOCK_RESERVADO < 0
   OR STOCK_DISPONIBLE IS NULL OR STOCK_DISPONIBLE < 0
   OR STOCK_RESERVADO > STOCK_FISICO
   OR STOCK_DISPONIBLE <> STOCK_FISICO - STOCK_RESERVADO

UNION ALL
SELECT '07', 'Movimientos con datos invalidos', COUNT(*)
FROM SMART_STORE_DW.STAGING.V_MOVIMIENTOS
WHERE MOVIMIENTO_ID IS NULL
   OR PRODUCTO_ID IS NULL
   OR FECHA_MOVIMIENTO IS NULL
   OR CANTIDAD IS NULL OR CANTIDAD <= 0

UNION ALL
SELECT '08', 'Eventos IoT invalidos o duplicados',
    (SELECT COUNT(*) FROM SMART_STORE_DW.STAGING.V_EVENTOS_IOT
     WHERE EVENT_ID IS NULL OR MOVIMIENTO_ID IS NULL
        OR FECHA_EVENTO IS NULL)
    +
    (SELECT COUNT(*) FROM (
        SELECT EVENT_ID
        FROM SMART_STORE_DW.STAGING.V_EVENTOS_IOT
        GROUP BY EVENT_ID
        HAVING COUNT(*) > 1
    ))

UNION ALL
SELECT '09', 'Eventos IoT sin movimiento', COUNT(*)
FROM SMART_STORE_DW.STAGING.V_EVENTOS_IOT I
LEFT JOIN SMART_STORE_DW.STAGING.V_MOVIMIENTOS M
    ON I.MOVIMIENTO_ID = M.MOVIMIENTO_ID
WHERE M.MOVIMIENTO_ID IS NULL

UNION ALL
SELECT '10', 'Fuentes operativas principales vacias',
    IFF(
        (SELECT COUNT(*) FROM SMART_STORE_DW.STAGING.V_PEDIDOS) = 0
        OR (SELECT COUNT(*) FROM SMART_STORE_DW.STAGING.V_PRODUCTOS) = 0
        OR (SELECT COUNT(*) FROM SMART_STORE_DW.STAGING.V_MOVIMIENTOS) = 0
        OR (SELECT COUNT(*) FROM SMART_STORE_DW.STAGING.V_EVENTOS_IOT) = 0,
        1, 0
    )
ORDER BY CODIGO
"""

POST_REFRESH_SQL = """
SELECT CODIGO, CONTROL, INCIDENCIAS
FROM SMART_STORE_DW.ANALYTICS.V_CALIDAD_DATOS
ORDER BY CODIGO
"""


def validate_quality(phase, sql, expected_controls=None):
    """Consulta controles y detiene el proceso ante incidencias."""
    connection = get_snowflake_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(sql)
            results = cursor.fetchall()
    finally:
        connection.close()

    if not results:
        raise RuntimeError(f"No se devolvieron controles: {phase}")

    if expected_controls is not None and len(results) != expected_controls:
        raise RuntimeError(
            f"{phase}: se esperaban {expected_controls} controles "
            f"y se recibieron {len(results)}"
        )

    print()
    print("=" * 60)
    print(phase)
    print("=" * 60)

    failures = []
    for code, description, count in results:
        if count is None or int(count) < 0:
            failures.append(f"{code}: resultado de control invalido")
            print(f"[REVISAR] {code} - {description}: {count}")
        elif int(count) > 0:
            failures.append(f"{code} - {description}: {count}")
            print(f"[REVISAR] {code} - {description}: {count}")
        else:
            print(f"[OK] {code} - {description}: 0")

    if failures:
        raise RuntimeError(
            f"{phase}: se detectaron incidencias. "
            "No se puede continuar. Detalles: "
            + "; ".join(failures)
        )

    print(f"CALIDAD CORRECTA: {len(results)} controles sin incidencias")


def refresh_data_warehouse():
    """Actualiza dimensiones y hechos mediante el procedimiento existente."""
    connection = get_snowflake_connection()
    try:
        with connection.cursor() as cursor:
            print()
            print("=" * 60)
            print("ACTUALIZANDO MODELO DIMENSIONAL")
            print("=" * 60)

            cursor.execute(f"CALL {PROCEDURE_NAME}()")
            result = cursor.fetchone()
            if result is None:
                raise RuntimeError("El procedimiento no devolvio resultado")

            message = str(result[0])
            if message != EXPECTED_RESULT:
                raise RuntimeError(f"Resultado inesperado: {message}")
            print(message)
    finally:
        connection.close()


def main():
    parser = argparse.ArgumentParser(
        description="Pipeline PostgreSQL-Snowflake con validaciones de calidad"
    )
    parser.add_argument(
        "--quality-only",
        action="store_true",
        help="Solo comprobar calidad, sin ETL ni cambios en Snowflake",
    )
    args = parser.parse_args()

    started = datetime.now()
    print("=" * 60)
    print("SMART STORE - PIPELINE CON CONTROL DE CALIDAD")
    print("=" * 60)
    print(f"Inicio: {started}")

    try:
        if not args.quality_only:
            print("\n[1/4] ETL POSTGRESQL -> RAW")
            run_etl()

        print("\n[2/4] CALIDAD PREVIA A ACTUALIZAR DW")
        validate_quality("CONTROLES PREVENTIVOS", PRE_REFRESH_SQL, 10)

        if not args.quality_only:
            print("\n[3/4] ACTUALIZANDO DATA WAREHOUSE")
            refresh_data_warehouse()

        print("\n[4/4] CALIDAD DE LOS DATOS ANALITICOS")
        validate_quality("CONTROLES FINALES", POST_REFRESH_SQL, 12)

        print("\n" + "=" * 60)
        if args.quality_only:
            print("VALIDACION COMPLETADA SIN MODIFICAR DATOS")
        else:
            print("PIPELINE COMPLETADO CORRECTAMENTE")
        print(f"Duracion: {datetime.now() - started}")
        print("=" * 60)

    except Exception as error:
        print("\n" + "=" * 60)
        print("PROCESO DETENIDO POR ERROR O CALIDAD INSUFICIENTE")
        print(str(error))
        print("=" * 60)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
