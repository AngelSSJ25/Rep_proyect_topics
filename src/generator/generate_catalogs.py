import random
from decimal import Decimal

from src.db import get_connection


SEED = 42
random.seed(SEED)

FECHA_INICIAL = "2025-11-01 08:00:00-05"

CATALOGOS = {

    "Tecnologia y electronica": [
        ("Audifonos inalambricos", 250, 1200),
        ("Teclado mecanico", 400, 1800),
        ("Mouse inalambrico", 150, 650),
        ("Cargador USB-C", 120, 600),
        ("Memoria USB", 100, 450),
        ("Bateria portatil", 250, 1000),
        ("Bocina Bluetooth", 300, 1500),
        ("Camara web", 350, 1400),
        ("Cable HDMI", 80, 350),
        ("Hub USB", 180, 800),
    ],

    "Hogar y cocina": [
        ("Sarten antiadherente", 250, 850),
        ("Termo de acero", 150, 650),
        ("Tabla para cortar", 100, 350),
        ("Juego de utensilios", 180, 600),
        ("Organizador de cocina", 150, 500),
        ("Juego de vasos", 120, 500),
        ("Recipiente hermetico", 80, 300),
        ("Lampara de escritorio", 250, 900),
        ("Set de cuchillos", 250, 1200),
        ("Balanza de cocina", 180, 600),
    ],

    "Accesorios personales": [
        ("Mochila urbana", 250, 1000),
        ("Cartera", 120, 500),
        ("Reloj digital", 200, 1500),
        ("Lentes de sol", 150, 700),
        ("Cinturon", 100, 450),
        ("Gorra", 120, 400),
        ("Bolsa de viaje", 300, 1200),
        ("Estuche de accesorios", 80, 350),
        ("Paraguas compacto", 120, 450),
        ("Neceser", 100, 400),
    ],

    "Deportes": [
        ("Mancuernas", 300, 1200),
        ("Banda de resistencia", 100, 350),
        ("Tapete de yoga", 200, 750),
        ("Botella deportiva", 100, 450),
        ("Cuerda para saltar", 80, 300),
        ("Guantes deportivos", 150, 500),
        ("Balon de futbol", 200, 800),
        ("Rodillera deportiva", 120, 450),
        ("Rodillo muscular", 180, 600),
        ("Mochila deportiva", 250, 900),
    ],

    "Oficina y papeleria": [
        ("Cuaderno profesional", 50, 200),
        ("Juego de boligrafos", 40, 180),
        ("Carpeta de documentos", 40, 150),
        ("Organizador de escritorio", 120, 450),
        ("Agenda", 80, 350),
        ("Calculadora", 100, 500),
        ("Grapadora", 70, 250),
        ("Juego de marcadores", 60, 250),
        ("Papel para impresora", 100, 300),
        ("Pizarra blanca", 200, 700),
    ],
}







def generate_categories_products(cursor):

    product_number = 1

    for category, products in CATALOGOS.items():

        cursor.execute("""
            INSERT INTO operacion.categorias (
                nombre, descripcion
            )
            VALUES (%s, %s)
            RETURNING categoria_id;
        """, (
            category,
            f"Categoria de productos de {category}"
        ))

        category_id = cursor.fetchone()[0]

        for product_name, min_price, max_price in products:

            for variant in ["Estandar", "Premium"]:

                price = Decimal(
                    random.randint(min_price, max_price)
                )

                if variant == "Premium":
                    price *= Decimal("1.25")

                price = price.quantize(Decimal("0.01"))

                cost = (
                    price * Decimal(
                        str(random.uniform(0.45, 0.75))
                    )
                ).quantize(Decimal("0.01"))

                sku = f"PRD-{product_number:05d}"

                barcode = f"750{product_number:010d}"

                brand = random.choice([
                    "Nova",
                    "Vertex",
                    "Prime",
                    "Urban",
                    "Nexus"
                ])

                cursor.execute("""
                    INSERT INTO operacion.productos (
                        categoria_id,
                        sku,
                        codigo_barras,
                        nombre,
                        descripcion,
                        marca,
                        precio_venta,
                        costo_unitario,
                        stock_minimo
                    )
                    VALUES (
                        %s, %s, %s, %s, %s,
                        %s, %s, %s, %s
                    );
                """, (
                    category_id,
                    sku,
                    barcode,
                    f"{product_name} {variant}",
                    f"{product_name} version {variant}",
                    brand,
                    price,
                    cost,
                    random.randint(5, 20)
                ))

                product_number += 1

    print("Categorias generadas: 5")
    print(f"Productos generados: {product_number - 1}")


def generate_suppliers(cursor):

    cities = [
        "Cancun",
        "Merida",
        "Guadalajara",
        "Monterrey",
        "Ciudad de Mexico"
    ]

    for number in range(1, 11):

        cursor.execute("""
            INSERT INTO operacion.proveedores (
                nombre,
                contacto,
                correo,
                ciudad,
                pais
            )
            VALUES (%s, %s, %s, %s, %s);
        """, (
            f"Distribuidora Comercial {number:02d}",
            f"Representante {number:02d}",
            f"proveedor{number:02d}@example.com",
            random.choice(cities),
            "Mexico"
        ))

    print("Proveedores generados: 10")



def generate_warehouses(cursor):

    warehouses = [
        (
            "ALM-CUN",
            "Almacen Cancun",
            "Cancun",
            "Quintana Roo"
        ),
        (
            "ALM-MID",
            "Almacen Merida",
            "Merida",
            "Yucatan"
        )
    ]

    location_count = 0
    device_count = 0

    for code, name, city, state in warehouses:

        cursor.execute("""
            INSERT INTO operacion.almacenes (
                codigo,
                nombre,
                ciudad,
                estado,
                capacidad_unidades
            )
            VALUES (%s, %s, %s, %s, %s)
            RETURNING almacen_id;
        """, (
            code,
            name,
            city,
            state,
            10000
        ))

        warehouse_id = cursor.fetchone()[0]

        location_ids = []

        # 4 zonas con 5 ubicaciones cada una

        for zone in ["A", "B", "C", "D"]:

            for number in range(1, 6):

                location_code = f"{zone}-{number:02d}"

                cursor.execute("""
                    INSERT INTO operacion.ubicaciones (
                        almacen_id,
                        codigo,
                        zona,
                        pasillo,
                        estante,
                        nivel,
                        capacidad
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING ubicacion_id;
                """, (
                    warehouse_id,
                    location_code,
                    zone,
                    f"{number:02d}",
                    f"{zone}{number:02d}",
                    "01",
                    500
                ))

                location_ids.append(cursor.fetchone()[0])
                location_count += 1

        # Dispositivos simulados del almacen

        devices = [
            ("REC", "Lector de recepcion", "RFID", None),
            ("ZONA-A", "Lector zona A", "RFID", location_ids[0]),
            ("ZONA-C", "Lector zona C", "RFID", location_ids[10]),
            ("PICK", "Lector de picking", "LECTOR_CODIGO_BARRAS", None),
            ("DESP", "Lector de despacho", "LECTOR_CODIGO_BARRAS", None)
        ]

        for suffix, device_name, device_type, location_id in devices:

            cursor.execute("""
                INSERT INTO operacion.dispositivos_iot (
                    almacen_id,
                    ubicacion_id,
                    codigo,
                    nombre,
                    tipo
                )
                VALUES (%s, %s, %s, %s, %s);
            """, (
                warehouse_id,
                location_id,
                f"{code}-{suffix}",
                device_name,
                device_type
            ))

            device_count += 1

    print(f"Almacenes generados: {len(warehouses)}")
    print(f"Ubicaciones generadas: {location_count}")
    print(f"Dispositivos IoT generados: {device_count}")








def main():

    random.seed(SEED)

    print("=" * 55)
    print("GENERACION DE CATALOGOS - SMART STORE")
    print("=" * 55)

    try:

        with get_connection() as conn:

            with conn.cursor() as cursor:

                # Evitar ejecutar dos veces el generador

                cursor.execute("""
                    SELECT
                        (SELECT COUNT(*) FROM operacion.categorias)
                        + (SELECT COUNT(*) FROM operacion.productos)
                        + (SELECT COUNT(*) FROM operacion.proveedores)
                        + (SELECT COUNT(*) FROM operacion.almacenes)
                        + (SELECT COUNT(*) FROM operacion.ubicaciones)
                        + (SELECT COUNT(*) FROM operacion.dispositivos_iot);
                """)

                existing_records = cursor.fetchone()[0]

                if existing_records > 0:
                    raise RuntimeError(
                        "Ya existen registros maestros. "
                        "No se generaran catalogos duplicados."
                    )

                # Establecer fecha historica inicial

                cursor.execute("""
                    SELECT set_config(
                        'smartstore.fecha_simulada',
                        %s,
                        TRUE
                    );
                """, (FECHA_INICIAL,))

                generate_categories_products(cursor)

                generate_suppliers(cursor)

                generate_warehouses(cursor)

            conn.commit()

        print("=" * 55)
        print("CATALOGOS GENERADOS CORRECTAMENTE")
        print("=" * 55)

    except Exception as error:

        print(f"ERROR: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()