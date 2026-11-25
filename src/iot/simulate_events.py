
import json
from collections import Counter
from pathlib import Path

from src.db import get_connection


BASE_DIR = Path(__file__).resolve().parents[2]

OUTPUT_DIR = BASE_DIR / "data" / "raw"

OUTPUT_FILE = OUTPUT_DIR / "iot_events.jsonl"


CLASIFICACIONES = {
    "RECEPCION": "ENTRADA",
    "UBICACION": "ALMACENAMIENTO",
    "TRASLADO": "MOVIMIENTO_INTERNO",
    "PICKING": "PREPARACION",
    "DESPACHO": "SALIDA",
    "VERIFICACION": "CONTROL_INVENTARIO",
    "DEVOLUCION": "ENTRADA"
}


def obtener_movimientos(cursor):
    cursor.execute("""
        SELECT
            m.movimiento_id,
            m.referencia_evento,
            m.tipo_movimiento,
            m.fecha_movimiento,
            m.cantidad,
            m.pedido_id,
            p.sku,
            p.codigo_barras,
            d.codigo AS dispositivo_codigo,
            d.tipo AS dispositivo_tipo,
            a.codigo AS almacen_codigo,
            uo.codigo AS ubicacion_origen,
            ud.codigo AS ubicacion_destino
        FROM operacion.movimientos_inventario m

        JOIN operacion.productos p
          ON p.producto_id = m.producto_id

        LEFT JOIN operacion.dispositivos_iot d
          ON d.dispositivo_id = m.dispositivo_id

        LEFT JOIN operacion.ubicaciones uo
          ON uo.ubicacion_id = m.ubicacion_origen_id

        LEFT JOIN operacion.ubicaciones ud
          ON ud.ubicacion_id = m.ubicacion_destino_id

        LEFT JOIN operacion.ubicaciones ub
          ON ub.ubicacion_id = COALESCE(
              m.ubicacion_origen_id,
              m.ubicacion_destino_id
          )

        LEFT JOIN operacion.almacenes a
          ON a.almacen_id = ub.almacen_id

        ORDER BY m.movimiento_id;
    """)

    columnas = [col.name for col in cursor.description]

    return [
        dict(zip(columnas, fila))
        for fila in cursor.fetchall()
    ]


def crear_evento(movimiento):
    tipo = movimiento["tipo_movimiento"]

    evento_id = (
        movimiento["referencia_evento"]
        or f"EVT-MOV-{movimiento['movimiento_id']}"
    )

    fecha = movimiento["fecha_movimiento"]

    return {
        "event_id": evento_id,
        "movement_id": movimiento["movimiento_id"],
        "source": "SIMULATED_WAREHOUSE_SCANNER",
        "event_type": tipo,
        "classification": CLASIFICACIONES.get(
            tipo, "OTRO"
        ),
        "timestamp": fecha.isoformat(),
        "device": {
            "code": movimiento["dispositivo_codigo"],
            "type": movimiento["dispositivo_tipo"]
        },
        "product": {
            "sku": movimiento["sku"],
            "barcode": movimiento["codigo_barras"],
            "quantity": movimiento["cantidad"]
        },
        "warehouse": movimiento["almacen_codigo"],
        "location": {
            "origin": movimiento["ubicacion_origen"],
            "destination": movimiento["ubicacion_destino"]
        },
        "order_id": movimiento["pedido_id"],
        "status": "SUCCESS"
    }


def generar_eventos():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    with get_connection() as conn:
        with conn.cursor() as cursor:
            movimientos = obtener_movimientos(cursor)

    if not movimientos:
        raise RuntimeError(
            "No existen movimientos para generar eventos IoT."
        )

    contador = Counter()

    # Archivo temporal para evitar un JSON incompleto
    temporal = OUTPUT_FILE.with_suffix(".jsonl.tmp")

    try:
        with temporal.open(
            "w",
            encoding="utf-8"
        ) as archivo:

            for movimiento in movimientos:
                evento = crear_evento(movimiento)

                archivo.write(
                    json.dumps(
                        evento,
                        ensure_ascii=False,
                        separators=(",", ":")
                    ) + "\n"
                )

                contador[evento["event_type"]] += 1

        temporal.replace(OUTPUT_FILE)

    finally:
        if temporal.exists():
            temporal.unlink()

    print("=" * 55)
    print("SIMULACION DE EVENTOS IOT - SMART STORE")
    print("=" * 55)

    for tipo, cantidad in sorted(contador.items()):
        print(f"{tipo}: {cantidad}")

    print("-" * 55)
    print(f"Total de eventos: {sum(contador.values())}")
    print(f"Archivo: {OUTPUT_FILE}")
    print("=" * 55)


if __name__ == "__main__":
    generar_eventos()
