
from datetime import datetime, timedelta, timezone

from src.db import get_connection


# ======================================================
# SMART STORE
# CORRECCION DE FECHAS HISTORICAS
# ======================================================

PRIMER_PEDIDO = 101
ULTIMO_PEDIDO = 2000
TOTAL_ESPERADO = 1900

ZONA_HORARIA = timezone(timedelta(hours=-5))

FECHA_INICIO = datetime(
    2025, 11, 12, 8, 0,
    tzinfo=ZONA_HORARIA
)

FECHA_FIN = datetime(
    2026, 11, 14, 18, 0,
    tzinfo=ZONA_HORARIA
)


def preparar_respaldo(cursor):
    """
    Crea una tabla independiente que conservara
    las fechas originales y las nuevas.
    """

    cursor.execute("""
        CREATE SCHEMA IF NOT EXISTS mantenimiento;
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS
        mantenimiento.ajuste_fechas_pedidos (
            pedido_id BIGINT PRIMARY KEY,
            numero_pedido VARCHAR(40) NOT NULL,
            fecha_original TIMESTAMPTZ NOT NULL,
            fecha_nueva TIMESTAMPTZ NOT NULL,
            fecha_ajuste TIMESTAMPTZ
                DEFAULT CURRENT_TIMESTAMP
        );
    """)

    cursor.execute("""
        SELECT COUNT(*)
        FROM mantenimiento.ajuste_fechas_pedidos;
    """)

    if cursor.fetchone()[0] > 0:
        raise RuntimeError(
            "El ajuste historico ya fue registrado. "
            "No se ejecutara nuevamente."
        )


def obtener_pedidos(cursor):
    """
    Obtiene exclusivamente los pedidos generados
    durante la ampliacion del dataset.
    """

    cursor.execute("""
        SELECT
            pedido_id,
            numero_pedido,
            fecha_pedido
        FROM operacion.pedidos
        WHERE numero_pedido ~ '^PED-[0-9]{6}$'
          AND SUBSTRING(
              numero_pedido FROM 5
          )::INTEGER BETWEEN %s AND %s
        ORDER BY
            SUBSTRING(
                numero_pedido FROM 5
            )::INTEGER;
    """, (PRIMER_PEDIDO, ULTIMO_PEDIDO))

    pedidos = cursor.fetchall()

    if len(pedidos) != TOTAL_ESPERADO:
        raise RuntimeError(
            f"Se esperaban {TOTAL_ESPERADO} pedidos, "
            f"pero se encontraron {len(pedidos)}. "
            "No se modifico ninguna fecha."
        )

    return pedidos


def crear_plan_fechas(cursor, pedidos):
    """
    Distribuye los pedidos uniformemente entre
    las fechas inicial y final.

    Se conserva el orden de los pedidos.
    """

    intervalo = (
        FECHA_FIN - FECHA_INICIO
    ) / (len(pedidos) - 1)

    registros = []

    for indice, pedido in enumerate(pedidos):
        pedido_id, numero_pedido, fecha_original = pedido

        fecha_nueva = (
            FECHA_INICIO + intervalo * indice
        )

        registros.append((
            pedido_id,
            numero_pedido,
            fecha_original,
            fecha_nueva
        ))

    cursor.executemany("""
        INSERT INTO mantenimiento.ajuste_fechas_pedidos (
            pedido_id,
            numero_pedido,
            fecha_original,
            fecha_nueva
        )
        VALUES (%s, %s, %s, %s);
    """, registros)


def ajustar_fechas(cursor):
    """
    Actualiza las fechas relacionadas con cada
    pedido manteniendo sus diferencias temporales.
    """

    # 1. Historial de estados

    cursor.execute("""
        UPDATE operacion.historial_pedidos h
        SET fecha_evento =
            h.fecha_evento +
            (a.fecha_nueva - a.fecha_original)
        FROM mantenimiento.ajuste_fechas_pedidos a
        WHERE h.pedido_id = a.pedido_id;
    """)

    historiales = cursor.rowcount

    # 2. Fechas de reservas

    cursor.execute("""
        UPDATE operacion.reservas_inventario r
        SET fecha_reserva =
            r.fecha_reserva +
            (a.fecha_nueva - a.fecha_original)
        FROM operacion.detalle_pedidos d,
             mantenimiento.ajuste_fechas_pedidos a
        WHERE r.detalle_id = d.detalle_id
          AND d.pedido_id = a.pedido_id;
    """)

    reservas = cursor.rowcount

    # 3. Movimientos vinculados a pedidos

    cursor.execute("""
        UPDATE operacion.movimientos_inventario m
        SET fecha_movimiento =
            m.fecha_movimiento +
            (a.fecha_nueva - a.fecha_original)
        FROM mantenimiento.ajuste_fechas_pedidos a
        WHERE m.pedido_id = a.pedido_id;
    """)

    movimientos = cursor.rowcount

    # 4. Fechas principales de los pedidos

    cursor.execute("""
        UPDATE operacion.pedidos p
        SET fecha_pedido = a.fecha_nueva
        FROM mantenimiento.ajuste_fechas_pedidos a
        WHERE p.pedido_id = a.pedido_id;
    """)

    pedidos = cursor.rowcount

    return {
        "pedidos": pedidos,
        "historiales": historiales,
        "reservas": reservas,
        "movimientos": movimientos
    }


def main():
    print("=" * 60)
    print("SMART STORE - CORRECCION HISTORICA")
    print("=" * 60)

    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:

                preparar_respaldo(cursor)

                pedidos = obtener_pedidos(cursor)

                crear_plan_fechas(cursor, pedidos)

                resultados = ajustar_fechas(cursor)

                # Los cambios se confirman juntos.
                # Si alguna operacion falla,
                # la transaccion se revierte.

        print("CORRECCION COMPLETADA")
        print("-" * 60)

        for entidad, cantidad in resultados.items():
            print(f"{entidad}: {cantidad}")

        print("-" * 60)
        print(f"Inicio del periodo: {FECHA_INICIO}")
        print(f"Fin del periodo: {FECHA_FIN}")

        print(
            "Respaldo: "
            "mantenimiento.ajuste_fechas_pedidos"
        )

        print("=" * 60)

    except Exception as error:
        print(f"ERROR: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
