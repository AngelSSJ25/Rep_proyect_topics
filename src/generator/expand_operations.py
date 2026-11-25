
import random
from collections import Counter
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from src.db import get_connection


SEED = 2026
TOTAL_OBJETIVO = 2000
PREFIJO_PEDIDO = "PED-"

rng = random.Random(SEED)
ZONA_HORARIA = timezone(timedelta(hours=-5))


def establecer_fecha(cursor, fecha):
    cursor.execute(
        """
        SELECT set_config(
            'smartstore.fecha_simulada',
            %s::TEXT,
            TRUE
        );
        """,
        (fecha.isoformat(),)
    )


def ejecutar_funcion(cursor, nombre, pedido_id):
    funciones = {
        "fn_confirmar_pedido",
        "fn_iniciar_preparacion",
        "fn_completar_preparacion",
        "fn_despachar_pedido",
        "fn_entregar_pedido",
        "fn_cancelar_pedido",
    }

    if nombre not in funciones:
        raise ValueError("Funcion no permitida")

    cursor.execute(
        f"SELECT operacion.{nombre}(%s::BIGINT);",
        (pedido_id,)
    )


def obtener_datos(cursor):
    cursor.execute("""
        SELECT cliente_id
        FROM operacion.clientes
        WHERE activo = TRUE
        ORDER BY cliente_id;
    """)
    clientes = [fila[0] for fila in cursor.fetchall()]

    cursor.execute("""
        SELECT producto_id
        FROM operacion.productos
        WHERE activo = TRUE
        ORDER BY producto_id;
    """)
    productos = [fila[0] for fila in cursor.fetchall()]

    cursor.execute("""
        SELECT proveedor_id
        FROM operacion.proveedores
        WHERE activo = TRUE
        ORDER BY proveedor_id;
    """)
    proveedores = [fila[0] for fila in cursor.fetchall()]

    cursor.execute("""
        SELECT
            d.dispositivo_id,
            d.almacen_id
        FROM operacion.dispositivos_iot d
        WHERE d.activo = TRUE
          AND d.codigo LIKE '%-REC'
        ORDER BY d.dispositivo_id;
    """)
    dispositivos = {
        fila[1]: fila[0]
        for fila in cursor.fetchall()
    }

    if not all([
        clientes,
        productos,
        proveedores,
        dispositivos
    ]):
        raise RuntimeError(
            "Faltan datos maestros para generar operaciones."
        )

    return clientes, productos, proveedores, dispositivos


def verificar_inventario(
    cursor,
    producto_id,
    cantidad,
    proveedores,
    dispositivos,
    referencia,
):
    cursor.execute("""
        SELECT COALESCE(SUM(stock_disponible), 0)
        FROM operacion.inventarios i
        JOIN operacion.ubicaciones u
          ON u.ubicacion_id = i.ubicacion_id
        JOIN operacion.almacenes a
          ON a.almacen_id = u.almacen_id
        WHERE i.producto_id = %s::BIGINT
          AND u.activo = TRUE
          AND a.activo = TRUE;
    """, (producto_id,))

    disponible = cursor.fetchone()[0]

    # Mantener un inventario minimo operativo
    if disponible >= cantidad + 20:
        return False

    cursor.execute("""
        SELECT
            u.ubicacion_id,
            u.almacen_id,
            u.capacidad
              - COALESCE(SUM(i.stock_fisico), 0)
                AS espacio_disponible,
            COALESCE(
                BOOL_OR(i.producto_id = %s::BIGINT),
                FALSE
            ) AS producto_existente
        FROM operacion.ubicaciones u
        JOIN operacion.almacenes a
          ON a.almacen_id = u.almacen_id
        LEFT JOIN operacion.inventarios i
          ON i.ubicacion_id = u.ubicacion_id
        WHERE u.activo = TRUE
          AND a.activo = TRUE
        GROUP BY
            u.ubicacion_id,
            u.almacen_id,
            u.capacidad
        HAVING u.capacidad
            - COALESCE(SUM(i.stock_fisico), 0) >= 80
        ORDER BY
            producto_existente DESC,
            espacio_disponible DESC,
            u.ubicacion_id
        LIMIT 1;
    """, (producto_id,))

    ubicacion = cursor.fetchone()

    if ubicacion is None:
        raise RuntimeError(
            "No hay capacidad para reabastecer el producto "
            f"{producto_id}"
        )

    ubicacion_id, almacen_id, _, _ = ubicacion

    proveedor_id = rng.choice(proveedores)
    dispositivo_id = dispositivos.get(almacen_id)

    if dispositivo_id is None:
        raise RuntimeError(
            f"No hay lector de recepcion en almacen {almacen_id}"
        )

    cursor.execute("""
        SELECT operacion.fn_recepcion_mercancia(
            %s::BIGINT,
            %s::BIGINT,
            %s::BIGINT,
            %s::INTEGER,
            %s::BIGINT,
            %s::VARCHAR
        );
    """, (
        producto_id,
        proveedor_id,
        ubicacion_id,
        80,
        dispositivo_id,
        referencia
    ))

    return True


def generar_operaciones():
    estados = Counter()
    reabastecimientos = 0

    with get_connection() as conn:
        with conn.cursor() as cursor:

            clientes, productos, proveedores, dispositivos = (
                obtener_datos(cursor)
            )

            cursor.execute("""
                SELECT
                    COUNT(*),
                    MAX(fecha_pedido)
                FROM operacion.pedidos;
            """)

            total_actual, ultima_fecha = cursor.fetchone()

            cursor.execute("""
                SELECT COALESCE(
                    MAX(
                        SUBSTRING(numero_pedido FROM 5)::INTEGER
                    ),
                    0
                )
                FROM operacion.pedidos
                WHERE numero_pedido ~ '^PED-[0-9]+$';
            """)

            ultimo_numero = cursor.fetchone()[0]

            if total_actual >= TOTAL_OBJETIVO:
                print(
                    "El objetivo de pedidos ya fue alcanzado."
                )
                return

            if ultima_fecha is None:
                ultima_fecha = datetime(
                    2025, 11, 10, 9, 0,
                    tzinfo=ZONA_HORARIA
                )

            fecha_actual = ultima_fecha + timedelta(minutes=15)

            faltantes = TOTAL_OBJETIVO - total_actual

            print("=" * 55)
            print("AMPLIACION DE OPERACIONES - SMART STORE")
            print("=" * 55)
            print(f"Pedidos existentes: {total_actual}")
            print(f"Pedidos por generar: {faltantes}")
            print("=" * 55)

            conn.commit()

            for indice in range(1, faltantes + 1):
                numero = ultimo_numero + indice

                # Intervalo entre nuevas compras
                fecha_actual += timedelta(
                    minutes=rng.randint(6, 10)
                )

                fecha_pedido = fecha_actual

                try:
                    # Seleccionar productos diferentes
                    seleccionados = rng.sample(
                        productos,
                        rng.randint(1, 3)
                    )

                    articulos = [
                        (producto_id, rng.randint(1, 2))
                        for producto_id in seleccionados
                    ]

                    # Reponer cuando exista poco inventario
                    # y ocasionalmente como abastecimiento normal
                    establecer_fecha(
                        cursor,
                        fecha_pedido - timedelta(minutes=2)
                    )

                    for producto_id, cantidad in articulos:
                        referencia = (
                            f"REAB-{numero:06d}-{producto_id}"
                        )

                        reponer = verificar_inventario(
                            cursor,
                            producto_id,
                            cantidad,
                            proveedores,
                            dispositivos,
                            referencia
                        )

                        if reponer:
                            reabastecimientos += 1

                    # Registrar pedido
                    establecer_fecha(cursor, fecha_pedido)

                    numero_pedido = f"{PREFIJO_PEDIDO}{numero:06d}"

                    cursor.execute("""
                        SELECT operacion.fn_crear_pedido(
                            %s::BIGINT,
                            %s::VARCHAR,
                            %s::VARCHAR,
                            %s::NUMERIC
                        );
                    """, (
                        rng.choice(clientes),
                        numero_pedido,
                        rng.choice([
                            "TARJETA",
                            "TRANSFERENCIA",
                            "EFECTIVO"
                        ]),
                        Decimal("49.00")
                    ))

                    pedido_id = cursor.fetchone()[0]

                    for producto_id, cantidad in articulos:
                        cursor.execute("""
                            SELECT operacion.fn_agregar_producto(
                                %s::BIGINT,
                                %s::BIGINT,
                                %s::INTEGER,
                                %s::NUMERIC
                            );
                        """, (
                            pedido_id,
                            producto_id,
                            cantidad,
                            Decimal("0.00")
                        ))

                    # Confirmacion
                    fecha = fecha_pedido + timedelta(minutes=1)
                    establecer_fecha(cursor, fecha)

                    ejecutar_funcion(
                        cursor, "fn_confirmar_pedido", pedido_id
                    )

                    resultado = rng.choices(
                        [
                            "ENTREGADO",
                            "CANCELADO",
                            "PREPARADO",
                            "CONFIRMADO"
                        ],
                        weights=[70, 15, 10, 5],
                        k=1
                    )[0]

                    if resultado == "CANCELADO":
                        fecha += timedelta(minutes=1)
                        establecer_fecha(cursor, fecha)

                        ejecutar_funcion(
                            cursor, "fn_cancelar_pedido", pedido_id
                        )

                    elif resultado != "CONFIRMADO":
                        fecha += timedelta(minutes=1)
                        establecer_fecha(cursor, fecha)

                        ejecutar_funcion(
                            cursor, "fn_iniciar_preparacion", pedido_id
                        )

                        fecha += timedelta(minutes=2)
                        establecer_fecha(cursor, fecha)

                        ejecutar_funcion(
                            cursor, "fn_completar_preparacion", pedido_id
                        )

                        if resultado == "ENTREGADO":
                            fecha += timedelta(minutes=2)
                            establecer_fecha(cursor, fecha)

                            ejecutar_funcion(
                                cursor, "fn_despachar_pedido", pedido_id
                            )

                            fecha += timedelta(days=2)
                            establecer_fecha(cursor, fecha)

                            ejecutar_funcion(
                                cursor, "fn_entregar_pedido", pedido_id
                            )

                    # Guardar cada pedido completado
                    conn.commit()
                    estados[resultado] += 1

                    if indice % 250 == 0:
                        print(
                            f"Progreso: {indice}/{faltantes} pedidos"
                        )

                except Exception as error:
                    conn.rollback()
                    print(
                        f"Error en pedido {numero}. "
                        "Transaccion revertida."
                    )
                    raise RuntimeError(
                        f"No se completo {numero_pedido if 'numero_pedido' in locals() else numero}"
                    ) from error

    print("=" * 55)
    print("AMPLIACION COMPLETADA")
    print("=" * 55)

    for estado, total in sorted(estados.items()):
        print(f"{estado}: {total}")

    print(f"Pedidos nuevos: {sum(estados.values())}")
    print(f"Reabastecimientos: {reabastecimientos}")
    print(f"Objetivo total: {TOTAL_OBJETIVO}")
    print("=" * 55)


if __name__ == "__main__":
    generar_operaciones()
