
-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 17 - DICCIONARIO DE DATOS
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ANALYTICS;
USE DATABASE SMART_STORE_DW;

CREATE SCHEMA IF NOT EXISTS GOVERNANCE;


-- =====================================================
-- DICCIONARIO TECNICO DEL DATA WAREHOUSE
-- =====================================================

CREATE OR REPLACE TABLE
    GOVERNANCE.DATA_DICTIONARY AS

SELECT
    C.TABLE_CATALOG AS BASE_DATOS,
    C.TABLE_SCHEMA AS ESQUEMA,
    C.TABLE_NAME AS OBJETO,
    T.TABLE_TYPE AS TIPO_OBJETO,
    C.ORDINAL_POSITION AS POSICION,
    C.COLUMN_NAME AS COLUMNA,
    C.DATA_TYPE AS TIPO_DATO,
    C.IS_NULLABLE AS PERMITE_NULOS,

    CASE C.TABLE_SCHEMA
        WHEN 'RAW' THEN
            'Almacenamiento de datos originales'
        WHEN 'STAGING' THEN
            'Limpieza y transformacion'
        WHEN 'DW' THEN
            'Modelo dimensional'
        WHEN 'ANALYTICS' THEN
            'Indicadores y reportes'
        WHEN 'GOVERNANCE' THEN
            'Metadatos y control'
        ELSE 'Otro'
    END AS CAPA,

    CASE
        WHEN C.TABLE_SCHEMA = 'DW'
             AND C.TABLE_NAME = 'FACT_VENTAS'
        THEN 'Detalle de ventas por producto y pedido'

        WHEN C.TABLE_SCHEMA = 'DW'
             AND C.TABLE_NAME = 'FACT_MOVIMIENTOS'
        THEN 'Movimientos logisticos vinculados a IoT'

        WHEN C.TABLE_SCHEMA = 'DW'
             AND C.TABLE_NAME = 'FACT_INVENTARIO_ACTUAL'
        THEN 'Existencias actuales por producto y ubicacion'

        WHEN C.TABLE_SCHEMA = 'DW'
             AND C.TABLE_NAME LIKE 'DIM_%'
        THEN 'Dimension descriptiva del modelo estrella'

        WHEN C.TABLE_SCHEMA = 'RAW'
             AND C.TABLE_NAME = 'IOT_EVENTS'
        THEN 'Eventos IoT originales en formato VARIANT'

        WHEN C.TABLE_SCHEMA = 'RAW'
             AND C.TABLE_NAME = 'POSTGRES_RECORDS'
        THEN 'Registros originales provenientes de PostgreSQL'

        WHEN C.TABLE_SCHEMA = 'STAGING'
        THEN 'Vista de conversion y preparacion de datos'

        WHEN C.TABLE_SCHEMA = 'ANALYTICS'
        THEN 'Vista para analisis e indicadores'

        ELSE 'Objeto de soporte del proyecto'
    END AS DESCRIPCION_OBJETO,

    CASE
        WHEN C.COLUMN_NAME LIKE '%_KEY'
        THEN 'Clave de relacion del modelo dimensional'

        WHEN C.COLUMN_NAME LIKE '%_ID'
        THEN 'Identificador del registro o entidad'

        WHEN C.COLUMN_NAME = 'EVENT_DATA'
        THEN 'Documento JSON del evento IoT'

        WHEN C.COLUMN_NAME = 'RECORD_DATA'
        THEN 'Documento JSON del registro operativo'

        WHEN C.COLUMN_NAME LIKE '%FECHA%'
             OR C.COLUMN_NAME LIKE '%TIMESTAMP%'
        THEN 'Fecha u hora relacionada con la operacion'

        WHEN C.COLUMN_NAME LIKE '%INGRESO%'
        THEN 'Importe monetario asociado a ingresos'

        WHEN C.COLUMN_NAME LIKE '%MARGEN%'
        THEN 'Resultado monetario de ingresos menos costos'

        WHEN C.COLUMN_NAME LIKE '%CANTIDAD%'
        THEN 'Cantidad de unidades de la operacion'

        WHEN C.COLUMN_NAME LIKE '%STOCK%'
        THEN 'Existencias registradas en inventario'

        ELSE 'Consultar definicion funcional del objeto'
    END AS DESCRIPCION_COLUMNA,

    CURRENT_TIMESTAMP() AS FECHA_DOCUMENTACION

FROM SMART_STORE_DW.INFORMATION_SCHEMA.COLUMNS C

JOIN SMART_STORE_DW.INFORMATION_SCHEMA.TABLES T
    ON C.TABLE_CATALOG = T.TABLE_CATALOG
   AND C.TABLE_SCHEMA = T.TABLE_SCHEMA
   AND C.TABLE_NAME = T.TABLE_NAME

WHERE C.TABLE_SCHEMA IN (
    'RAW',
    'STAGING',
    'DW',
    'ANALYTICS',
    'GOVERNANCE'
)

AND NOT (
    C.TABLE_SCHEMA = 'GOVERNANCE'
    AND C.TABLE_NAME = 'DATA_DICTIONARY'
);


-- =====================================================
-- RESUMEN DEL DICCIONARIO
-- =====================================================

SELECT
    ESQUEMA,
    COUNT(DISTINCT OBJETO) AS OBJETOS,
    COUNT(*) AS COLUMNAS_DOCUMENTADAS
FROM GOVERNANCE.DATA_DICTIONARY
GROUP BY ESQUEMA
ORDER BY ESQUEMA;
