
-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 16 - VALIDACION DE PERMISOS RBAC
-- =====================================================

-- 1. Utilizar el rol administrador
USE ROLE ACCOUNTADMIN;

-- 2. Asignar temporalmente el rol de analista
-- al usuario de Snowflake utilizado en el proyecto.
-- El permiso expirara despues de una hora.

GRANT ROLE SMART_ANALYST_ROLE
    TO USER ANGELBALAM
    FOR INTERVAL '1 HOUR';


-- 3. Cambiar al rol de analista
USE ROLE SMART_ANALYST_ROLE;

-- 4. Desactivar roles secundarios para comprobar
-- exclusivamente los permisos del rol seleccionado
USE SECONDARY ROLES NONE;

-- 5. Usar el warehouse permitido al analista
USE WAREHOUSE WH_SMART_ANALYTICS;

-- 6. Confirmar el rol activo y consultar informacion
SELECT
    CURRENT_ROLE() AS ROL_ACTIVO,
    CURRENT_WAREHOUSE() AS WAREHOUSE_ACTUAL,
    COUNT(*) AS MESES_CON_INFORMACION
FROM SMART_STORE_DW.ANALYTICS.V_VENTAS_MENSUALES;


-- 7. Restaurar el contexto administrativo
USE ROLE ACCOUNTADMIN;
USE SECONDARY ROLES ALL;
