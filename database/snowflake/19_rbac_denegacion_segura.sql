-- SMART STORE - PRUEBA NEGATIVA SEGURA DE RBAC
-- ATENCION: ejecutar por bloques, NO Run All.
-- El UPDATE termina con error esperado si RBAC esta configurado bien.
-- WHERE 1=0 garantiza que no se modifican filas aun si no falla.

-- BLOQUE A: ejecutar primero estas instrucciones.
USE ROLE ACCOUNTADMIN;
GRANT ROLE SMART_ANALYST_ROLE TO USER ANGELBALAM FOR INTERVAL '1 HOUR';
USE ROLE SMART_ANALYST_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE WH_SMART_ANALYTICS;
SELECT CURRENT_ROLE() AS ROL_ACTIVO;

-- BLOQUE B: SELECCIONAR SOLO ESTA SENTENCIA Y PULSAR Run.
-- Resultado correcto esperado: SQL access control error/Insufficient privileges.
UPDATE SMART_STORE_DW.DW.FACT_VENTAS
SET CANTIDAD = CANTIDAD
WHERE 1 = 0;

-- BLOQUE C: ejecutar individualmente despues de guardar la evidencia.
USE ROLE ACCOUNTADMIN;
USE SECONDARY ROLES ALL;

-- NOTA: Si el UPDATE se ejecuta sin error, el rol analista posee
-- algun acceso de escritura inesperado o heredado; los datos no
-- habran cambiado por la condicion WHERE 1=0 y se revisan GRANTs.
