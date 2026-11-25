
import random

from src.db import get_connection


SEED = 42
FECHA_INICIAL = "2025-11-03 08:00:00-05"


def generate_initial_stock(cursor):
    rng = random.Random(SEED)

    # Obtener los productos existentes
    cursor.execute("""
        SELECT producto_id, sku
        FROM operacion.productos
        WHERE activo = TRUE
        ORDER BY producto_id;
    """)
    productos = cursor.fetchall()

    # Obtener proveedores
    cursor.execute("""
        SELECT proveedor_id
        FROM operacion.proveedores
        WHERE activo = TRUE
        ORDER BY proveedor_id;
    """)
    proveedores = [fila[0] for fila in cursor.fetchall()]

    # Obtener almacenes
    cursor.execute("""
        SELECT almacen_id, codigo
        FROM operacion.almacenes
        WHERE activo = TRUE
        ORDER BY almacen_id;
    """)
    almacenes = cursor.fetchall()

    if not productos or not proveedores or not almacenes:
        raise RuntimeError(
            "Faltan productos, proveedores o almacenes."
        )

    total_movimientos = 0
    total_unidades = 0

    for almacen_id, codigo_almacen in almacenes:

        # Ubicaciones disponibles del almacen
        cursor.execute("""
            SELECT ubicacion_id
            FROM operacion.ubicaciones
            WHERE almacen_id = %s
              AND activo = TRUE
            ORDER BY ubicacion_id;
        """, (almacen_id,))

        ubicaciones = [
            fila[0] for fila in cursor.fetchall()
        ]

        # Dispositivo de recepcion
        cursor.execute("""
            SELECT dispositivo_id
            FROM operacion.dispositivos_iot
            WHERE almacen_id = %s
              AND activo = TRUE
              AND codigo LIKE %s
            ORDER BY dispositivo_id
            LIMIT 1;
        """, (almacen_id, f"{codigo_almacen}-REC"))

        dispositivo = cursor.fetchone()

        if not ubicaciones or dispositivo is None:
            raise RuntimeError(
                f"Almacen {codigo_almacen} incompleto."
            )

        dispositivo_id = dispositivo[0]
        unidades_almacen = 0

        for indice, (producto_id, sku) in enumerate(productos):

            # Distribuir productos entre ubicaciones
            ubicacion_id = ubicaciones[
                indice % len(ubicaciones)
            ]

            # Cantidad inicial por producto
            cantidad = rng.randint(40, 85)

            proveedor_id = rng.choice(proveedores)

            # Referencia unica para trazabilidad
            referencia = (
                f"INIT-{codigo_almacen}-{sku}"
            )

            cursor.execute("""
                SELECT operacion.fn_recepcion_mercancia(
                    %s, %s, %s, %s, %s, %s
                );
            """, (
                producto_id,
                proveedor_id,
                ubicacion_id,
                cantidad,
                dispositivo_id,
                referencia
            ))

            total_movimientos += 1
            total_unidades += cantidad
            unidades_almacen += cantidad

        print(
            f"{codigo_almacen}: "
            f"{unidades_almacen} unidades recibidas"
        )

    return total_movimientos, total_unidades


def main():

    print("=" * 55)
    print("ABASTECIMIENTO INICIAL - SMART STORE")
    print("=" * 55)

    try:
        with get_connection() as conn:

            with conn.cursor() as cursor:

                # Evitar ejecutar nuevamente la carga inicial
                cursor.execute("""
                    SELECT
                        (SELECT COUNT(*)
                         FROM operacion.inventarios),
                        (SELECT COUNT(*)
                         FROM operacion.movimientos_inventario);
                """)

                inventarios, movimientos = cursor.fetchone()

                if inventarios > 0 or movimientos > 0:
                    raise RuntimeError(
                        "Ya existen inventarios o movimientos. "
                        "No se realizara una nueva carga inicial."
                    )

                # Establecer fecha historica
                cursor.execute("""
                    SELECT set_config(
                        'smartstore.fecha_simulada',
                        %s,
                        TRUE
                    );
                """, (FECHA_INICIAL,))

                movimientos, unidades = generate_initial_stock(
                    cursor
                )

            # La transaccion se confirma al salir
            # correctamente del bloque de conexion.

        print("=" * 55)
        print("ABASTECIMIENTO COMPLETADO")
        print(f"Movimientos generados: {movimientos}")
        print(f"Unidades recibidas: {unidades}")
        print("=" * 55)

    except Exception as error:
        print(f"ERROR: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
