
-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 11 - GOBERNANZA: CONTROL DE ACCESO RBAC
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE SMART_STORE_DW;


-- =====================================================
-- 1. CREAR ROLES DEL PROYECTO
-- =====================================================

CREATE ROLE IF NOT EXISTS SMART_ETL_ROLE
    COMMENT = 'Rol operativo para cargas ETL';

CREATE ROLE IF NOT EXISTS SMART_ANALYST_ROLE
    COMMENT = 'Rol de consulta de datos analiticos';


-- =====================================================
-- 2. ACCESO BASICO A LA BASE DE DATOS
-- =====================================================

GRANT USAGE ON DATABASE SMART_STORE_DW
    TO ROLE SMART_ETL_ROLE;

GRANT USAGE ON DATABASE SMART_STORE_DW
    TO ROLE SMART_ANALYST_ROLE;


-- =====================================================
-- 3. WAREHOUSES
-- =====================================================

GRANT USAGE ON WAREHOUSE WH_SMART_ETL
    TO ROLE SMART_ETL_ROLE;

GRANT USAGE ON WAREHOUSE WH_SMART_ANALYTICS
    TO ROLE SMART_ANALYST_ROLE;


-- =====================================================
-- 4. PERMISOS DEL ROL ETL
-- =====================================================

GRANT USAGE ON SCHEMA SMART_STORE_DW.RAW
    TO ROLE SMART_ETL_ROLE;

GRANT USAGE ON SCHEMA SMART_STORE_DW.STAGING
    TO ROLE SMART_ETL_ROLE;

GRANT USAGE ON SCHEMA SMART_STORE_DW.DW
    TO ROLE SMART_ETL_ROLE;

GRANT SELECT, INSERT, UPDATE
    ON TABLE SMART_STORE_DW.RAW.POSTGRES_RECORDS
    TO ROLE SMART_ETL_ROLE;

GRANT SELECT, INSERT, UPDATE
    ON TABLE SMART_STORE_DW.RAW.ETL_EXECUTIONS
    TO ROLE SMART_ETL_ROLE;

GRANT SELECT
    ON TABLE SMART_STORE_DW.RAW.IOT_EVENTS
    TO ROLE SMART_ETL_ROLE;

GRANT SELECT
    ON ALL VIEWS IN SCHEMA SMART_STORE_DW.STAGING
    TO ROLE SMART_ETL_ROLE;

GRANT SELECT, INSERT, UPDATE
    ON ALL TABLES IN SCHEMA SMART_STORE_DW.DW
    TO ROLE SMART_ETL_ROLE;

GRANT USAGE
    ON PROCEDURE SMART_STORE_DW.DW.SP_REFRESH_DW()
    TO ROLE SMART_ETL_ROLE;


-- =====================================================
-- 5. PERMISOS DEL ANALISTA
-- =====================================================

GRANT USAGE ON SCHEMA SMART_STORE_DW.ANALYTICS
    TO ROLE SMART_ANALYST_ROLE;

GRANT SELECT
    ON ALL VIEWS IN SCHEMA SMART_STORE_DW.ANALYTICS
    TO ROLE SMART_ANALYST_ROLE;

-- Vistas analiticas que se creen posteriormente
GRANT SELECT
    ON FUTURE VIEWS IN SCHEMA SMART_STORE_DW.ANALYTICS
    TO ROLE SMART_ANALYST_ROLE;


-- =====================================================
-- 6. JERARQUIA DE ROLES
-- =====================================================

GRANT ROLE SMART_ETL_ROLE TO ROLE SYSADMIN;

GRANT ROLE SMART_ANALYST_ROLE TO ROLE SYSADMIN;


-- =====================================================
-- RESULTADO
-- =====================================================

SHOW ROLES LIKE 'SMART_%_ROLE';
