
-- ============================================================
-- SMART STORE DATA WAREHOUSE
-- 12 - GOBERNANZA: CALIDAD DE DATOS
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ANALYTICS;
USE DATABASE SMART_STORE_DW;
USE SCHEMA ANALYTICS;


-- ============================================================
-- VISTA DE CONTROLES DE CALIDAD
-- ============================================================

CREATE OR REPLACE VIEW ANALYTICS.V_CALIDAD_DATOS AS

WITH CONTROLES AS (

    -- 1. Registros duplicados en RAW

    SELECT
        '01' AS CODIGO,
        'Duplicados en RAW PostgreSQL' AS CONTROL,
        (
            SELECT COUNT(*)
            FROM RAW.POSTGRES_RECORDS
        ) -
        (
            SELECT COUNT(DISTINCT
                SOURCE_TABLE || ':' || RECORD_ID)
            FROM RAW.POSTGRES_RECORDS
        ) AS INCIDENCIAS

    UNION ALL

    -- 2. Detalles de venta duplicados

    SELECT
        '02',
        'Duplicados en FACT_VENTAS',
        (
            SELECT COUNT(*)
            FROM DW.FACT_VENTAS
        ) -
        (
            SELECT COUNT(DISTINCT VENTA_KEY)
            FROM DW.FACT_VENTAS
        )

    UNION ALL

    -- 3. Movimientos duplicados

    SELECT
        '03',
        'Duplicados en FACT_MOVIMIENTOS',
        (
            SELECT COUNT(*)
            FROM DW.FACT_MOVIMIENTOS
        ) -
        (
            SELECT COUNT(DISTINCT MOVIMIENTO_KEY)
            FROM DW.FACT_MOVIMIENTOS
        )

    UNION ALL

    -- 4. Ventas sin producto valido

    SELECT
        '04',
        'Ventas sin producto asociado',
        COUNT(*)
    FROM DW.FACT_VENTAS V
    LEFT JOIN DW.DIM_PRODUCTO P
        ON V.PRODUCTO_KEY = P.PRODUCTO_KEY
    WHERE P.PRODUCTO_KEY IS NULL

    UNION ALL

    -- 5. Ventas sin cliente valido

    SELECT
        '05',
        'Ventas sin cliente asociado',
        COUNT(*)
    FROM DW.FACT_VENTAS V
    LEFT JOIN DW.DIM_CLIENTE C
        ON V.CLIENTE_KEY = C.CLIENTE_KEY
    WHERE C.CLIENTE_KEY IS NULL

    UNION ALL

    -- 6. Cantidades o importes invalidos

    SELECT
        '06',
        'Cantidades e importes invalidos',
        COUNT(*)
    FROM DW.FACT_VENTAS
    WHERE CANTIDAD IS NULL
       OR CANTIDAD <= 0
       OR PRECIO_UNITARIO IS NULL
       OR PRECIO_UNITARIO < 0
       OR IMPORTE_PEDIDO IS NULL
       OR IMPORTE_PEDIDO < 0

    UNION ALL

    -- 7. Inventario inconsistente

    SELECT
        '07',
        'Inconsistencias de inventario',
        COUNT(*)
    FROM DW.FACT_INVENTARIO_ACTUAL
    WHERE STOCK_FISICO IS NULL
       OR STOCK_RESERVADO IS NULL
       OR STOCK_DISPONIBLE IS NULL
       OR STOCK_FISICO < 0
       OR STOCK_RESERVADO < 0
       OR STOCK_DISPONIBLE < 0
       OR STOCK_RESERVADO > STOCK_FISICO
       OR STOCK_DISPONIBLE <>
            STOCK_FISICO - STOCK_RESERVADO

    UNION ALL

    -- 8. Movimientos sin producto valido

    SELECT
        '08',
        'Movimientos sin producto asociado',
        COUNT(*)
    FROM DW.FACT_MOVIMIENTOS M
    LEFT JOIN DW.DIM_PRODUCTO P
        ON M.PRODUCTO_KEY = P.PRODUCTO_KEY
    WHERE P.PRODUCTO_KEY IS NULL

    UNION ALL

    -- 9. Movimientos sin evento IoT

    SELECT
        '09',
        'Movimientos sin evento IoT',
        COUNT(*)
    FROM DW.FACT_MOVIMIENTOS
    WHERE EVENTO_IOT_ID IS NULL

    UNION ALL

    -- 10. Eventos IoT duplicados

    SELECT
        '10',
        'Eventos IoT duplicados',
        (
            SELECT COUNT(*)
            FROM RAW.IOT_EVENTS
        ) -
        (
            SELECT COUNT(DISTINCT
                EVENT_DATA:event_id::VARCHAR)
            FROM RAW.IOT_EVENTS
        )

    UNION ALL

    -- 11. Eventos IoT sin movimiento

    SELECT
        '11',
        'Eventos IoT sin movimiento',
        COUNT(*)
    FROM STAGING.V_EVENTOS_IOT I
    LEFT JOIN DW.FACT_MOVIMIENTOS M
        ON I.MOVIMIENTO_ID = M.MOVIMIENTO_ID
    WHERE M.MOVIMIENTO_ID IS NULL

    UNION ALL

    -- 12. Fechas de venta sin dimension

    SELECT
        '12',
        'Ventas sin fecha dimensional',
        COUNT(*)
    FROM DW.FACT_VENTAS V
    LEFT JOIN DW.DIM_FECHA F
        ON V.FECHA_KEY = F.FECHA_KEY
    WHERE F.FECHA_KEY IS NULL

)

SELECT
    CODIGO,
    CONTROL,
    INCIDENCIAS,
    CASE
        WHEN INCIDENCIAS = 0 THEN 'CORRECTO'
        ELSE 'REVISAR'
    END AS ESTADO
FROM CONTROLES;


-- ============================================================
-- RESUMEN DE CALIDAD
-- ============================================================

SELECT
    COUNT(*) AS CONTROLES_EJECUTADOS,
    COUNT_IF(ESTADO = 'CORRECTO') AS CORRECTOS,
    COUNT_IF(ESTADO = 'REVISAR') AS REVISAR,
    SUM(INCIDENCIAS) AS TOTAL_INCIDENCIAS
FROM ANALYTICS.V_CALIDAD_DATOS;
