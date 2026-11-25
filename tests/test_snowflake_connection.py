
from src.snowflake_db import get_snowflake_connection


def main():
    with get_snowflake_connection() as conn:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    CURRENT_DATABASE(),
                    CURRENT_SCHEMA(),
                    CURRENT_WAREHOUSE();
            """)

            database, schema, warehouse = cursor.fetchone()

            print("=" * 50)
            print("CONEXION EXITOSA A SNOWFLAKE")
            print("=" * 50)
            print(f"Base de datos: {database}")
            print(f"Esquema: {schema}")
            print(f"Warehouse: {warehouse}")
            print("=" * 50)


if __name__ == "__main__":
    main()
