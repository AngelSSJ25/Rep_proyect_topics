import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv


# Ubicacion principal del proyecto
BASE_DIR = Path(__file__).resolve().parent.parent

# Cargar las variables de entorno
load_dotenv(BASE_DIR / ".env")


def get_connection():
    """
    Establece una conexion con PostgreSQL.
    """

    password = os.getenv("DB_PASSWORD")

    if not password:
        raise ValueError(
            "No se encontro DB_PASSWORD en el archivo .env"
        )

    return psycopg.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "5432")),
        dbname=os.getenv("DB_NAME", "smart_store_db"),
        user=os.getenv("DB_USER", "postgres"),
        password=password,
        connect_timeout=10
    )