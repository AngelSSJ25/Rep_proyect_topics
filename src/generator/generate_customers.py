import random

from faker import Faker
from src.db import get_connection


SEED = 42
TOTAL_CUSTOMERS = 500

random.seed(SEED)

fake = Faker("es_MX")
Faker.seed(SEED)

FECHA_INICIAL = "2025-11-01 08:00:00-05"


LOCATIONS = [
    ("Cancun", "Quintana Roo"),
    ("Playa del Carmen", "Quintana Roo"),
    ("Chetumal", "Quintana Roo"),
    ("Merida", "Yucatan"),
    ("Valladolid", "Yucatan"),
    ("Campeche", "Campeche"),
    ("Monterrey", "Nuevo Leon"),
    ("Guadalajara", "Jalisco"),
    ("Puebla", "Puebla"),
    ("Ciudad de Mexico", "Ciudad de Mexico"),
    ("Toluca", "Estado de Mexico"),
    ("Veracruz", "Veracruz")
]


def generate_customers(cursor, total):

    customers = []

    for number in range(1, total + 1):

        first_name = fake.first_name()
        last_name = fake.last_name()

        city, state = random.choice(LOCATIONS)

        email = f"cliente{number:06d}@example.com"

        phone = None

        customers.append((
            first_name,
            last_name,
            email,
            phone,
            city,
            state,
            "Mexico",
            True
        ))

    cursor.executemany("""
        INSERT INTO operacion.clientes (
            nombre,
            apellido,
            correo,
            telefono,
            ciudad,
            estado,
            pais,
            activo
        )
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
    """, customers)

    print(f"Clientes generados: {len(customers)}")


def main():

    print("=" * 55)
    print("GENERACION DE CLIENTES - SMART STORE")
    print("=" * 55)

    try:

        with get_connection() as conn:

            with conn.cursor() as cursor:

                cursor.execute("""
                    SELECT COUNT(*)
                    FROM operacion.clientes;
                """)

                if cursor.fetchone()[0] > 0:
                    raise RuntimeError(
                        "Ya existen clientes registrados."
                    )

                cursor.execute("""
                    SELECT set_config(
                        'smartstore.fecha_simulada',
                        %s,
                        TRUE
                    );
                """, (FECHA_INICIAL,))

                generate_customers(
                    cursor,
                    TOTAL_CUSTOMERS
                )

            conn.commit()

        print("=" * 55)
        print("CLIENTES GENERADOS CORRECTAMENTE")
        print("=" * 55)

    except Exception as error:

        print(f"ERROR: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()