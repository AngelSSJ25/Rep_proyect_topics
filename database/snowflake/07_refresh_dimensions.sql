
-- ============================================================
-- SMART STORE DATA WAREHOUSE
-- 07 - ACTUALIZACION DE DIMENSIONES CON MERGE
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ETL;
USE DATABASE SMART_STORE_DW;
USE SCHEMA DW;


-- ============================================================
-- 1. DIMENSION PRODUCTO
-- ============================================================

MERGE INTO DW.DIM_PRODUCTO AS T
USING (
    SELECT
        P.PRODUCTO_ID AS PRODUCTO_KEY,
        P.PRODUCTO_ID,
        P.SKU,
        P.CODIGO_BARRAS,
        P.NOMBRE AS PRODUCTO,
        P.MARCA,
        P.CATEGORIA_ID,
        C.NOMBRE AS CATEGORIA,
        P.PRECIO_VENTA AS PRECIO_ACTUAL,
        P.COSTO_UNITARIO AS COSTO_ACTUAL,
        P.STOCK_MINIMO,
        P.ACTIVO
    FROM STAGING.V_PRODUCTOS P
    LEFT JOIN STAGING.V_CATEGORIAS C
        ON P.CATEGORIA_ID = C.CATEGORIA_ID
) AS S

ON T.PRODUCTO_KEY = S.PRODUCTO_KEY

WHEN MATCHED THEN
    UPDATE ALL BY NAME

WHEN NOT MATCHED THEN
    INSERT ALL BY NAME;


-- ============================================================
-- 2. DIMENSION CLIENTE
-- ============================================================

MERGE INTO DW.DIM_CLIENTE AS T
USING (
    SELECT
        CLIENTE_ID AS CLIENTE_KEY,
        CLIENTE_ID,
        NOMBRE,
        APELLIDO,
        CIUDAD,
        ESTADO,
        PAIS,
        ACTIVO,
        FECHA_REGISTRO
    FROM STAGING.V_CLIENTES
) AS S

ON T.CLIENTE_KEY = S.CLIENTE_KEY

WHEN MATCHED THEN
    UPDATE ALL BY NAME

WHEN NOT MATCHED THEN
    INSERT ALL BY NAME;


-- ============================================================
-- 3. DIMENSION ALMACEN
-- ============================================================

MERGE INTO DW.DIM_ALMACEN AS T
USING (
    SELECT
        ALMACEN_ID AS ALMACEN_KEY,
        ALMACEN_ID,
        CODIGO,
        NOMBRE AS ALMACEN,
        CIUDAD,
        ESTADO,
        CAPACIDAD_UNIDADES,
        ACTIVO
    FROM STAGING.V_ALMACENES
) AS S

ON T.ALMACEN_KEY = S.ALMACEN_KEY

WHEN MATCHED THEN
    UPDATE ALL BY NAME

WHEN NOT MATCHED THEN
    INSERT ALL BY NAME;


-- ============================================================
-- 4. DIMENSION UBICACION
-- ============================================================

MERGE INTO DW.DIM_UBICACION AS T
USING (
    SELECT
        U.UBICACION_ID AS UBICACION_KEY,
        U.UBICACION_ID,
        U.ALMACEN_ID,
        A.CODIGO AS CODIGO_ALMACEN,
        U.CODIGO AS CODIGO_UBICACION,
        U.ZONA,
        U.PASILLO,
        U.ESTANTE,
        U.NIVEL,
        U.CAPACIDAD,
        U.ACTIVO
    FROM STAGING.V_UBICACIONES U
    LEFT JOIN STAGING.V_ALMACENES A
        ON U.ALMACEN_ID = A.ALMACEN_ID
) AS S

ON T.UBICACION_KEY = S.UBICACION_KEY

WHEN MATCHED THEN
    UPDATE ALL BY NAME

WHEN NOT MATCHED THEN
    INSERT ALL BY NAME;


-- ============================================================
-- 5. DIMENSION DISPOSITIVO IOT
-- ============================================================

MERGE INTO DW.DIM_DISPOSITIVO AS T
USING (
    SELECT
        D.DISPOSITIVO_ID AS DISPOSITIVO_KEY,
        D.DISPOSITIVO_ID,
        D.CODIGO,
        D.NOMBRE AS DISPOSITIVO,
        D.TIPO,
        D.ALMACEN_ID,
        A.CODIGO AS CODIGO_ALMACEN,
        D.UBICACION_ID,
        D.ACTIVO
    FROM STAGING.V_DISPOSITIVOS D
    LEFT JOIN STAGING.V_ALMACENES A
        ON D.ALMACEN_ID = A.ALMACEN_ID
) AS S

ON T.DISPOSITIVO_KEY = S.DISPOSITIVO_KEY

WHEN MATCHED THEN
    UPDATE ALL BY NAME

WHEN NOT MATCHED THEN
    INSERT ALL BY NAME;


-- ============================================================
-- FIN DE ACTUALIZACION DE DIMENSIONES
-- ============================================================

SELECT
    'ACTUALIZACION DE DIMENSIONES COMPLETADA'
        AS RESULTADO;
