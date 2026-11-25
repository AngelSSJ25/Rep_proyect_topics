
-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 15 - CONSULTAS DEL DASHBOARD EJECUTIVO
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ANALYTICS;
USE DATABASE SMART_STORE_DW;
USE SCHEMA ANALYTICS;


-- =====================================================
-- PANEL 1: INDICADORES GENERALES
-- =====================================================

SELECT
    SUM(PEDIDOS_TOTALES) AS PEDIDOS,
    SUM(PEDIDOS_ENTREGADOS) AS ENTREGADOS,
    ROUND(SUM(INGRESOS), 2) AS INGRESOS_MXN,
    ROUND(SUM(MARGEN_BRUTO), 2) AS MARGEN_MXN,
    ROUND(
        100.0 * SUM(PEDIDOS_ENTREGADOS)
        / NULLIF(SUM(PEDIDOS_TOTALES), 0), 2
    ) AS TASA_ENTREGA_PCT
FROM ANALYTICS.V_VENTAS_MENSUALES;


-- =====================================================
-- PANEL 2: TENDENCIAS MENSUALES
-- =====================================================

SELECT
    PERIODO,
    PEDIDOS_TOTALES,
    PEDIDOS_ENTREGADOS,
    INGRESOS,
    MARGEN_BRUTO
FROM ANALYTICS.V_VENTAS_MENSUALES
ORDER BY PERIODO;


-- =====================================================
-- PANEL 3: RENDIMIENTO POR CATEGORIA
-- =====================================================

SELECT
    CATEGORIA,
    SUM(UNIDADES_VENDIDAS) AS UNIDADES,
    ROUND(SUM(INGRESOS), 2) AS INGRESOS_MXN,
    ROUND(SUM(MARGEN_BRUTO), 2) AS MARGEN_MXN
FROM ANALYTICS.V_PRODUCTOS_MAS_VENDIDOS
GROUP BY CATEGORIA
ORDER BY INGRESOS_MXN DESC;


-- =====================================================
-- PANEL 4: EFICIENCIA DE ALMACENES
-- =====================================================

SELECT
    ALMACEN,
    MOVIMIENTOS_TOTALES,
    RECEPCIONES,
    OPERACIONES_PICKING,
    DESPACHOS,
    UNIDADES_RECIBIDAS,
    UNIDADES_DESPACHADAS,
    COBERTURA_IOT_PCT
FROM ANALYTICS.V_EFICIENCIA_ALMACEN
ORDER BY ALMACEN;
