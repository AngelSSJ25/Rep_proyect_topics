-- =====================================================
-- SMART STORE DATA WAREHOUSE
-- 09 - PROCEDIMIENTO DE ACTUALIZACION DW
-- Archivo generado automaticamente desde 07 y 08
-- =====================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ETL;
USE DATABASE SMART_STORE_DW;
USE SCHEMA DW;

ALTER SESSION SET ERROR_ON_NONDETERMINISTIC_MERGE = TRUE;

CREATE OR REPLACE PROCEDURE
    SMART_STORE_DW.DW.SP_REFRESH_DW()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN

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

    MERGE INTO DW.FACT_VENTAS AS T
    
    USING (
        SELECT
            D.DETALLE_ID AS VENTA_KEY,
            D.DETALLE_ID,
            D.PEDIDO_ID,
            P.NUMERO_PEDIDO,
    
            TO_NUMBER(
                TO_CHAR(P.FECHA_PEDIDO::DATE, 'YYYYMMDD')
            ) AS FECHA_KEY,
    
            P.FECHA_PEDIDO,
            P.CLIENTE_ID AS CLIENTE_KEY,
            D.PRODUCTO_ID AS PRODUCTO_KEY,
    
            P.ESTADO AS ESTADO_PEDIDO,
            P.METODO_PAGO,
            P.MONEDA,
    
            D.CANTIDAD,
            D.PRECIO_UNITARIO,
            D.COSTO_UNITARIO,
            D.DESCUENTO,
    
            (D.CANTIDAD * D.PRECIO_UNITARIO)
                AS IMPORTE_BRUTO,
    
            D.SUBTOTAL AS IMPORTE_PEDIDO,
    
            (D.CANTIDAD * D.COSTO_UNITARIO)
                AS COSTO_MERCANCIA,
    
            CASE
                WHEN P.ESTADO = 'ENTREGADO'
                THEN D.SUBTOTAL
                ELSE 0
            END AS INGRESO_REALIZADO,
    
            CASE
                WHEN P.ESTADO = 'ENTREGADO'
                THEN D.SUBTOTAL -
                    (D.CANTIDAD * D.COSTO_UNITARIO)
                ELSE 0
            END AS MARGEN_REALIZADO
    
        FROM STAGING.V_DETALLE_PEDIDOS D
    
        INNER JOIN STAGING.V_PEDIDOS P
            ON D.PEDIDO_ID = P.PEDIDO_ID
    
    ) AS S
    
    ON T.VENTA_KEY = S.VENTA_KEY
    
    WHEN MATCHED
        AND T.ESTADO_PEDIDO IS DISTINCT FROM S.ESTADO_PEDIDO
            OR FALSE
    THEN UPDATE ALL BY NAME
    
    WHEN MATCHED
        AND HASH(T.IMPORTE_PEDIDO, T.CANTIDAD,
                 T.PRECIO_UNITARIO, T.COSTO_UNITARIO,
                 T.DESCUENTO, T.METODO_PAGO,
                 T.MONEDA, T.FECHA_PEDIDO,
                 T.CLIENTE_KEY, T.PRODUCTO_KEY)
            <> HASH(S.IMPORTE_PEDIDO, S.CANTIDAD,
                    S.PRECIO_UNITARIO, S.COSTO_UNITARIO,
                    S.DESCUENTO, S.METODO_PAGO,
                    S.MONEDA, S.FECHA_PEDIDO,
                    S.CLIENTE_KEY, S.PRODUCTO_KEY)
    THEN UPDATE ALL BY NAME
    
    WHEN NOT MATCHED
    THEN INSERT ALL BY NAME;

    MERGE INTO DW.FACT_MOVIMIENTOS AS T
    
    USING (
        SELECT
            M.MOVIMIENTO_ID AS MOVIMIENTO_KEY,
            M.MOVIMIENTO_ID,
            M.PEDIDO_ID,
    
            TO_NUMBER(
                TO_CHAR(
                    M.FECHA_MOVIMIENTO::DATE,
                    'YYYYMMDD'
                )
            ) AS FECHA_KEY,
    
            M.FECHA_MOVIMIENTO,
            M.PRODUCTO_ID AS PRODUCTO_KEY,
            M.DISPOSITIVO_ID AS DISPOSITIVO_KEY,
    
            COALESCE(
                UO.ALMACEN_ID,
                UD.ALMACEN_ID
            ) AS ALMACEN_KEY,
    
            M.UBICACION_ORIGEN_ID
                AS UBICACION_ORIGEN_KEY,
    
            M.UBICACION_DESTINO_ID
                AS UBICACION_DESTINO_KEY,
    
            M.TIPO_MOVIMIENTO,
            M.CANTIDAD,
            M.REFERENCIA_EVENTO,
    
            I.EVENT_ID AS EVENTO_IOT_ID,
            I.TIPO_EVENTO AS TIPO_EVENTO_IOT,
            I.CLASIFICACION AS CLASIFICACION_IOT,
            I.CODIGO_DISPOSITIVO,
            I.ESTADO AS ESTADO_EVENTO_IOT,
    
            CASE
                WHEN M.TIPO_MOVIMIENTO
                    IN ('RECEPCION', 'DEVOLUCION')
                THEN M.CANTIDAD
                ELSE 0
            END AS UNIDADES_ENTRADA,
    
            CASE
                WHEN M.TIPO_MOVIMIENTO = 'DESPACHO'
                THEN M.CANTIDAD
                ELSE 0
            END AS UNIDADES_SALIDA
    
        FROM STAGING.V_MOVIMIENTOS M
    
        LEFT JOIN STAGING.V_UBICACIONES UO
            ON M.UBICACION_ORIGEN_ID = UO.UBICACION_ID
    
        LEFT JOIN STAGING.V_UBICACIONES UD
            ON M.UBICACION_DESTINO_ID = UD.UBICACION_ID
    
        LEFT JOIN (
            SELECT *
            FROM STAGING.V_EVENTOS_IOT
            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY MOVIMIENTO_ID
                ORDER BY FECHA_EVENTO DESC, EVENT_ID DESC
            ) = 1
        ) I
            ON M.MOVIMIENTO_ID = I.MOVIMIENTO_ID
    
    ) AS S
    
    ON T.MOVIMIENTO_KEY = S.MOVIMIENTO_KEY
    
    WHEN MATCHED AND (
        HASH(
            T.PEDIDO_ID,
            T.FECHA_KEY,
            T.FECHA_MOVIMIENTO,
            T.PRODUCTO_KEY,
            T.DISPOSITIVO_KEY,
            T.ALMACEN_KEY,
            T.UBICACION_ORIGEN_KEY,
            T.UBICACION_DESTINO_KEY,
            T.TIPO_MOVIMIENTO,
            T.CANTIDAD,
            T.REFERENCIA_EVENTO,
            T.EVENTO_IOT_ID,
            T.TIPO_EVENTO_IOT,
            T.CLASIFICACION_IOT,
            T.CODIGO_DISPOSITIVO,
            T.ESTADO_EVENTO_IOT
        )
        <>
        HASH(
            S.PEDIDO_ID,
            S.FECHA_KEY,
            S.FECHA_MOVIMIENTO,
            S.PRODUCTO_KEY,
            S.DISPOSITIVO_KEY,
            S.ALMACEN_KEY,
            S.UBICACION_ORIGEN_KEY,
            S.UBICACION_DESTINO_KEY,
            S.TIPO_MOVIMIENTO,
            S.CANTIDAD,
            S.REFERENCIA_EVENTO,
            S.EVENTO_IOT_ID,
            S.TIPO_EVENTO_IOT,
            S.CLASIFICACION_IOT,
            S.CODIGO_DISPOSITIVO,
            S.ESTADO_EVENTO_IOT
        )
    )
    THEN UPDATE ALL BY NAME
    
    WHEN NOT MATCHED
    THEN INSERT ALL BY NAME;

    MERGE INTO DW.FACT_INVENTARIO_ACTUAL AS T
    
    USING (
        SELECT
            I.INVENTARIO_ID,
            I.PRODUCTO_ID AS PRODUCTO_KEY,
            I.UBICACION_ID AS UBICACION_KEY,
            U.ALMACEN_ID AS ALMACEN_KEY,
    
            I.STOCK_FISICO,
            I.STOCK_RESERVADO,
            I.STOCK_DISPONIBLE,
            I.ACTUALIZADO_EN
    
        FROM STAGING.V_INVENTARIOS I
    
        LEFT JOIN STAGING.V_UBICACIONES U
            ON I.UBICACION_ID = U.UBICACION_ID
    
    ) AS S
    
    ON T.INVENTARIO_ID = S.INVENTARIO_ID
    
    WHEN MATCHED AND (
        HASH(
            T.PRODUCTO_KEY,
            T.UBICACION_KEY,
            T.ALMACEN_KEY,
            T.STOCK_FISICO,
            T.STOCK_RESERVADO,
            T.STOCK_DISPONIBLE,
            T.ACTUALIZADO_EN
        )
        <>
        HASH(
            S.PRODUCTO_KEY,
            S.UBICACION_KEY,
            S.ALMACEN_KEY,
            S.STOCK_FISICO,
            S.STOCK_RESERVADO,
            S.STOCK_DISPONIBLE,
            S.ACTUALIZADO_EN
        )
    )
    THEN UPDATE ALL BY NAME
    
    WHEN NOT MATCHED
    THEN INSERT ALL BY NAME;

    RETURN 'ACTUALIZACION DEL DATA WAREHOUSE COMPLETADA';

END;
$$;

-- Ejecutar el procedimiento una vez
CALL SMART_STORE_DW.DW.SP_REFRESH_DW();
