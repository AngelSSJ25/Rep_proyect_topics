from src.db import get_connection


def test_connection():

    try:

        with get_connection() as conn:

            with conn.cursor() as cursor:

                # Verificar conexion
                cursor.execute("""
                    SELECT
                        current_database(),
                        current_user,
                        version();
                """)

                database, user, version = cursor.fetchone()

                print("=" * 55)
                print("CONEXION EXITOSA A POSTGRESQL")
                print("=" * 55)

                print(f"Base de datos: {database}")
                print(f"Usuario: {user}")
                print(f"Version: {version}")

                # Verificar tablas
                cursor.execute("""
                    SELECT COUNT(*)
                    FROM information_schema.tables
                    WHERE table_schema = 'operacion'
                      AND table_type = 'BASE TABLE';
                """)

                total_tables = cursor.fetchone()[0]

                print(f"Tablas encontradas: {total_tables}")

                # Verificar funciones
                cursor.execute("""
                    SELECT COUNT(*)
                    FROM information_schema.routines
                    WHERE routine_schema = 'operacion'
                      AND routine_type = 'FUNCTION';
                """)

                total_functions = cursor.fetchone()[0]

                print(f"Funciones encontradas: {total_functions}")

                # Verificar datos existentes
                cursor.execute("""
                    SELECT COUNT(*)
                    FROM operacion.productos;
                """)

                total_products = cursor.fetchone()[0]

                print(f"Productos registrados: {total_products}")

                if total_tables != 13 or total_functions != 15:
                    raise RuntimeError(
                        "La estructura de PostgreSQL no coincide "
                        "con la esperada."
                    )

                print("=" * 55)
                print("ENTORNO LISTO PARA GENERAR DATOS")
                print("=" * 55)

    except Exception as error:

        print(f"ERROR: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    test_connection()