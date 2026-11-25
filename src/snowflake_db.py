
import os
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / ".env")


def get_snowflake_connection():
    """
    Establece una conexion con Snowflake usando
    autenticacion nativa MFA o un token PAT.
    """

    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")

    authenticator = os.getenv(
        "SNOWFLAKE_AUTHENTICATOR",
        "username_password_mfa"
    ).strip().lower()

    if not account or not user:
        raise ValueError(
            "Faltan SNOWFLAKE_ACCOUNT o "
            "SNOWFLAKE_USER en .env"
        )

    config = {
        "account": account,
        "user": user,
        "role": os.getenv(
            "SNOWFLAKE_ROLE", "ACCOUNTADMIN"
        ),
        "warehouse": os.getenv(
            "SNOWFLAKE_WAREHOUSE", "WH_SMART_ETL"
        ),
        "database": os.getenv(
            "SNOWFLAKE_DATABASE", "SMART_STORE_DW"
        ),
        "schema": os.getenv(
            "SNOWFLAKE_SCHEMA", "RAW"
        ),
        "login_timeout": 60,
        "enable_server_session_keep_alive_auto_detection": False
    }

    if authenticator in (
        "snowflake",
        "username_password_mfa"
    ):
        password = os.getenv("SNOWFLAKE_PASSWORD")

        if not password:
            raise ValueError(
                "Falta SNOWFLAKE_PASSWORD en .env"
            )

        config["authenticator"] = authenticator
        config["password"] = password

    elif authenticator == "programmatic_access_token":
        token = os.getenv("SNOWFLAKE_TOKEN")

        if not token:
            raise ValueError(
                "Falta SNOWFLAKE_TOKEN en .env"
            )

        config["authenticator"] = (
            "PROGRAMMATIC_ACCESS_TOKEN"
        )
        config["token"] = token

    elif authenticator == "externalbrowser":
        config["authenticator"] = "externalbrowser"

    else:
        raise ValueError(
            f"Metodo de autenticacion no soportado: "
            f"{authenticator}"
        )

    return snowflake.connector.connect(**config)
