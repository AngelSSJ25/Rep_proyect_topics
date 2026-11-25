
import random
from collections import Counter
from datetime import datetime, timedelta, timezone

from src.db import get_connection


SEED = 42
TOTAL_PEDIDOS = 100

ZONA_HORARIA = timezone(timedelta(hours=-5))
FECHA_INICIO = datetime(
    2025, 11, 10, 9, 0,
    tzinfo=ZONA_HORARIA
)

rng = random.Random(SEED)


def establecer_fecha(cursor, fecha):
    cursor.execute(
        """
        SELECT set_config(
            'smartstore.fecha_simulada',
            %s,
            TRUE
        );
        """,
        (fecha.isoformat(),)
    )


def ejecutar_funcion(cursor, nombre, pedido_id):
    funciones_permitidas = {
        "fn_confirmar_pedido",
        "fn_iniciar_preparacion",
        "fn_completar_preparacion",
        "fn_despachar_pedido",
        "fn_entregar_pedido",
        "fn_cancelar_pedido",
    }

    if nombre not in funciones_permitidas:
        raise ValueError("Funcion no permitida")

    cursor.execute(
        f"SELECT operacion.{nombre}(%s::BIGINT);",
        (pedido_id,)
    )


def generar_pedidos():
    estados = Counter()

    with get_connection() as conn:
        with conn.cursor() as cursor:

            cursor.execute(
                "SELECT COUNT(*) FROM operacion.pedidos;"
            )

            if cursor.fetchone()[0] > 0:
                raise RuntimeError(
                    "Ya existen pedidos. "
                    "Se cancela la generacion para evitar duplicados."
                )

            cursor.execute("""
                SELECT cliente_id
                FROM operacion.clientes
                WHERE activo = TRUE;
            """)
            clientes = [f[0] for f in cursor.fetchall()]

            cursor.execute("""
                SELECT producto_id
                FROM operacion.productos
                WHERE activo = TRUE;
            """)
            productos = [f[0] for f in cursor.fetchall()]

            if not clientes or not productos:
                raise RuntimeError(
                    "No existen clientes o productos."
                )

            # Fechas distribuidas durante doce meses
            fechas = sorted(
                FECHA_INICIO + timedelta(
                    days=rng.randint(0, 364),
                    hours=rng.randint(0, 10),
                    minutes=rng.randint(0, 59)
                )
                for _ in range(TOTAL_PEDIDOS)
            )

            conn.commit()

            for numero, fecha in enumerate(fechas, 1):

                try:
                    establecer_fecha(cursor, fecha)

                    cliente_id = rng.choice(clientes)
                    numero_pedido = f"PED-{numero:06d}"

                    cursor.execute("""
                        SELECT operacion.fn_crear_pedido(
                            %s::BIGINT,
                            %s::VARCHAR, 
                            %s::VARCHAR, 
                            %s::NUMERIC
                        );
                    """, (
                        cliente_id,
                        numero_pedido,
                        "TARJETA",
                        49.00
                    ))

                    pedido_id = cursor.fetchone()[0]

                    seleccionados = rng.sample(
                        productos,
                        rng.randint(1, 3)
                    )

                    for producto_id in seleccionados:
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
                            rng.randint(1, 2),
                            0
                        ))

                    fecha += timedelta(minutes=1)
                    establecer_fecha(cursor, fecha)

                    ejecutar_funcion(
                        cursor,
                        "fn_confirmar_pedido",
                        pedido_id
                    )

                    # Distribucion de estados
                    resultado = rng.choices(
                        ["ENTREGADO", "CANCELADO",
                         "PREPARADO", "CONFIRMADO"],
                        weights=[70, 15, 10, 5],
                        k=1
                    )[0]

                    if resultado == "CANCELADO":

                        fecha += timedelta(minutes=15)
                        establecer_fecha(cursor, fecha)

                        ejecutar_funcion(
                            cursor,
                            "fn_cancelar_pedido",
                            pedido_id
                        )

                    elif resultado != "CONFIRMADO":

                        fecha += timedelta(minutes=10)
                        establecer_fecha(cursor, fecha)

                        ejecutar_funcion(
                            cursor,
                            "fn_iniciar_preparacion",
                            pedido_id
                        )

                        fecha += timedelta(minutes=30)
                        establecer_fecha(cursor, fecha)

                        ejecutar_funcion(
                            cursor,
                            "fn_completar_preparacion",
                            pedido_id
                        )

                        if resultado == "ENTREGADO":

                            fecha += timedelta(hours=2)
                            establecer_fecha(cursor, fecha)

                            ejecutar_funcion(
                                cursor,
                                "fn_despachar_pedido",
                                pedido_id
                            )

                            fecha += timedelta(days=2)
                            establecer_fecha(cursor, fecha)

                            ejecutar_funcion(
                                cursor,
                                "fn_entregar_pedido",
                                pedido_id
                            )

                    conn.commit()
                    estados[resultado] += 1

                except Exception:
                    conn.rollback()
                    print(
                        f"Error en pedido {numero}. "
                        "Transaccion revertida."
                    )
                    raise

    print("=" * 50)
    print("GENERACION DE OPERACIONES COMPLETADA")
    print("=" * 50)

    for estado, total in sorted(estados.items()):
        print(f"{estado}: {total}")

    print(f"Total de pedidos: {sum(estados.values())}")


if __name__ == "__main__":
    generar_pedidos()
