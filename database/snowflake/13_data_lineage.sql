
-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 13 - GOBERNANZA: LINAJE DE DATOS
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ANALYTICS;
USE DATABASE SMART_STORE_DW;

-- Esquema dedicado a metadatos de gobernanza
CREATE SCHEMA IF NOT EXISTS GOVERNANCE;

-- Documentacion declarativa del flujo de datos
CREATE OR REPLACE TABLE GOVERNANCE.DATA_LINEAGE AS

SELECT
    COLUMN1::VARCHAR AS FUENTE,
    COLUMN2::VARCHAR AS DESTINO,
    COLUMN3::VARCHAR AS PROCESO,
    COLUMN4::VARCHAR AS DESCRIPCION

FROM VALUES

(
    'PostgreSQL.operacion',
    'RAW.POSTGRES_RECORDS',
    'Python ETL / MERGE',
    'Extraccion de las 13 tablas operativas'
),
(
    'data/raw/iot_events.jsonl',
    'RAW.IOT_EVENTS',
    'Simulacion IoT / COPY INTO / MERGE',
    'Carga y sincronizacion de eventos JSON'
),
(
    'RAW.POSTGRES_RECORDS',
    'STAGING.V_PRODUCTOS',
    'SQL VIEW',
    'Conversion de productos a columnas tipadas'
),
(
    'RAW.POSTGRES_RECORDS',
    'STAGING.V_PEDIDOS',
    'SQL VIEW',
    'Conversion de pedidos a columnas tipadas'
),
(
    'RAW.POSTGRES_RECORDS',
    'STAGING.V_MOVIMIENTOS',
    'SQL VIEW',
    'Conversion de movimientos de almacen'
),
(
    'RAW.IOT_EVENTS',
    'STAGING.V_EVENTOS_IOT',
    'SQL VIEW',
    'Extraccion de atributos JSON VARIANT'
),
(
    'STAGING.V_PRODUCTOS',
    'DW.DIM_PRODUCTO',
    'MERGE',
    'Actualizacion de dimension de productos'
),
(
    'STAGING.V_CLIENTES',
    'DW.DIM_CLIENTE',
    'MERGE',
    'Actualizacion de dimension de clientes'
),
(
    'STAGING.V_PEDIDOS + STAGING.V_DETALLE_PEDIDOS',
    'DW.FACT_VENTAS',
    'MERGE',
    'Construccion de hechos de ventas'
),
(
    'STAGING.V_MOVIMIENTOS + STAGING.V_EVENTOS_IOT',
    'DW.FACT_MOVIMIENTOS',
    'MERGE',
    'Integracion de movimientos y lecturas IoT'
),
(
    'DW.FACT_VENTAS + DW.DIM_FECHA',
    'ANALYTICS.V_VENTAS_MENSUALES',
    'SQL VIEW',
    'Calculo de indicadores mensuales'
),
(
    'DW.FACT_VENTAS + DW.DIM_PRODUCTO',
    'ANALYTICS.V_RANKING_PRODUCTOS',
    'SQL VIEW',
    'Clasificacion comercial de productos'
),
(
    'DW.FACT_MOVIMIENTOS + DW.DIM_ALMACEN',
    'ANALYTICS.V_EFICIENCIA_ALMACEN',
    'SQL VIEW',
    'Indicadores de operaciones logisticas'
);

-- Resumen de la documentacion
SELECT
    COUNT(*) AS RELACIONES_DOCUMENTADAS
FROM GOVERNANCE.DATA_LINEAGE;
