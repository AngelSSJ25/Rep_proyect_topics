
-- =====================================================
-- SMART STORE
-- CARGA INICIAL DE EVENTOS IOT EN SNOWFLAKE
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ETL;
USE DATABASE SMART_STORE_DW;
USE SCHEMA RAW;

-- Cargar los eventos JSON desde el stage interno.
-- Snowflake registra los archivos cargados para
-- evitar recargas accidentales del mismo archivo.

COPY INTO RAW.IOT_EVENTS (
    EVENT_DATA,
    SOURCE_FILE
)
FROM (
    SELECT
        t.$1,
        METADATA$FILENAME
    FROM @RAW.STG_IOT_EVENTS
        (FILE_FORMAT => 'RAW.FF_IOT_JSON') t
)
ON_ERROR = ABORT_STATEMENT
FORCE = FALSE;

-- Resumen de los eventos cargados

SELECT
    COUNT(*) AS TOTAL_EVENTOS,
    COUNT(DISTINCT EVENT_DATA:event_id::STRING)
        AS EVENTOS_UNICOS,
    COUNT(DISTINCT EVENT_DATA:device.code::STRING)
        AS DISPOSITIVOS,
    MIN(EVENT_DATA:timestamp::TIMESTAMP_TZ)
        AS PRIMER_EVENTO,
    MAX(EVENT_DATA:timestamp::TIMESTAMP_TZ)
        AS ULTIMO_EVENTO
FROM RAW.IOT_EVENTS;
