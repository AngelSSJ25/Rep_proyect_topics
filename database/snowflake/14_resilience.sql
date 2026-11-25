
-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 14 - RESILIENCIA: ZERO-COPY CLONING Y TIME TRAVEL
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ETL;
USE DATABASE SMART_STORE_DW;

-- Esquema independiente para recuperacion
CREATE SCHEMA IF NOT EXISTS RESILIENCE;


-- =====================================================
-- 1. CREAR CLON DE FACT_VENTAS
-- =====================================================

CREATE TABLE IF NOT EXISTS
    RESILIENCE.FACT_VENTAS_CLON
CLONE DW.FACT_VENTAS;


-- =====================================================
-- 2. SIMULAR ELIMINACION ACCIDENTAL DEL CLON
-- =====================================================

DROP TABLE RESILIENCE.FACT_VENTAS_CLON;


-- =====================================================
-- 3. RECUPERAR UTILIZANDO TIME TRAVEL
-- =====================================================

UNDROP TABLE RESILIENCE.FACT_VENTAS_CLON;


-- =====================================================
-- 4. RESULTADO DE RECUPERACION
-- =====================================================

SELECT
    (SELECT COUNT(*)
     FROM DW.FACT_VENTAS)
        AS REGISTROS_ORIGINALES,

    (SELECT COUNT(*)
     FROM RESILIENCE.FACT_VENTAS_CLON)
        AS REGISTROS_RECUPERADOS,

    CASE
        WHEN
            (SELECT COUNT(*) FROM DW.FACT_VENTAS)
            =
            (SELECT COUNT(*)
             FROM RESILIENCE.FACT_VENTAS_CLON)
        THEN 'RECUPERACION EXITOSA'
        ELSE 'REVISAR'
    END AS RESULTADO;
