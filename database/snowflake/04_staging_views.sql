
-- ============================================================
-- SMART STORE DATA WAREHOUSE
-- 04 - TRANSFORMACIONES STAGING
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_SMART_ETL;
USE DATABASE SMART_STORE_DW;
USE SCHEMA STAGING;


-- ============================================================
-- 1. CATEGORIAS
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_CATEGORIAS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:categoria_id::STRING)
        AS CATEGORIA_ID,
    RECORD_DATA:nombre::VARCHAR AS NOMBRE,
    RECORD_DATA:descripcion::VARCHAR AS DESCRIPCION,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'categorias';


-- ============================================================
-- 2. PRODUCTOS
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_PRODUCTOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:producto_id::STRING)
        AS PRODUCTO_ID,
    TRY_TO_NUMBER(RECORD_DATA:categoria_id::STRING)
        AS CATEGORIA_ID,
    RECORD_DATA:sku::VARCHAR AS SKU,
    RECORD_DATA:codigo_barras::VARCHAR AS CODIGO_BARRAS,
    RECORD_DATA:nombre::VARCHAR AS NOMBRE,
    RECORD_DATA:marca::VARCHAR AS MARCA,
    TRY_TO_DECIMAL(
        RECORD_DATA:precio_venta::STRING, 14, 2
    ) AS PRECIO_VENTA,
    TRY_TO_DECIMAL(
        RECORD_DATA:costo_unitario::STRING, 14, 2
    ) AS COSTO_UNITARIO,
    TRY_TO_NUMBER(RECORD_DATA:stock_minimo::STRING)
        AS STOCK_MINIMO,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:fecha_creacion::STRING
    ) AS FECHA_CREACION
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'productos';


-- ============================================================
-- 3. CLIENTES
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_CLIENTES AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:cliente_id::STRING)
        AS CLIENTE_ID,
    RECORD_DATA:nombre::VARCHAR AS NOMBRE,
    RECORD_DATA:apellido::VARCHAR AS APELLIDO,
    RECORD_DATA:correo::VARCHAR AS CORREO,
    RECORD_DATA:ciudad::VARCHAR AS CIUDAD,
    RECORD_DATA:estado::VARCHAR AS ESTADO,
    RECORD_DATA:pais::VARCHAR AS PAIS,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:fecha_registro::STRING
    ) AS FECHA_REGISTRO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'clientes';


-- ============================================================
-- 4. PROVEEDORES
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_PROVEEDORES AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:proveedor_id::STRING)
        AS PROVEEDOR_ID,
    RECORD_DATA:nombre::VARCHAR AS NOMBRE,
    RECORD_DATA:ciudad::VARCHAR AS CIUDAD,
    RECORD_DATA:pais::VARCHAR AS PAIS,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'proveedores';


-- ============================================================
-- 5. ALMACENES
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_ALMACENES AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:almacen_id::STRING)
        AS ALMACEN_ID,
    RECORD_DATA:codigo::VARCHAR AS CODIGO,
    RECORD_DATA:nombre::VARCHAR AS NOMBRE,
    RECORD_DATA:ciudad::VARCHAR AS CIUDAD,
    RECORD_DATA:estado::VARCHAR AS ESTADO,
    TRY_TO_NUMBER(
        RECORD_DATA:capacidad_unidades::STRING
    ) AS CAPACIDAD_UNIDADES,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'almacenes';


-- ============================================================
-- 6. UBICACIONES
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_UBICACIONES AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:ubicacion_id::STRING)
        AS UBICACION_ID,
    TRY_TO_NUMBER(RECORD_DATA:almacen_id::STRING)
        AS ALMACEN_ID,
    RECORD_DATA:codigo::VARCHAR AS CODIGO,
    RECORD_DATA:zona::VARCHAR AS ZONA,
    RECORD_DATA:pasillo::VARCHAR AS PASILLO,
    RECORD_DATA:estante::VARCHAR AS ESTANTE,
    RECORD_DATA:nivel::VARCHAR AS NIVEL,
    TRY_TO_NUMBER(RECORD_DATA:capacidad::STRING)
        AS CAPACIDAD,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'ubicaciones';


-- ============================================================
-- 7. DISPOSITIVOS IOT
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_DISPOSITIVOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:dispositivo_id::STRING)
        AS DISPOSITIVO_ID,
    TRY_TO_NUMBER(RECORD_DATA:almacen_id::STRING)
        AS ALMACEN_ID,
    TRY_TO_NUMBER(RECORD_DATA:ubicacion_id::STRING)
        AS UBICACION_ID,
    RECORD_DATA:codigo::VARCHAR AS CODIGO,
    RECORD_DATA:nombre::VARCHAR AS NOMBRE,
    RECORD_DATA:tipo::VARCHAR AS TIPO,
    RECORD_DATA:activo::BOOLEAN AS ACTIVO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'dispositivos_iot';


-- ============================================================
-- 8. PEDIDOS
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_PEDIDOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:pedido_id::STRING)
        AS PEDIDO_ID,
    TRY_TO_NUMBER(RECORD_DATA:cliente_id::STRING)
        AS CLIENTE_ID,
    RECORD_DATA:numero_pedido::VARCHAR AS NUMERO_PEDIDO,
    RECORD_DATA:estado::VARCHAR AS ESTADO,
    RECORD_DATA:metodo_pago::VARCHAR AS METODO_PAGO,
    TRY_TO_DECIMAL(
        RECORD_DATA:costo_envio::STRING, 14, 2
    ) AS COSTO_ENVIO,
    RECORD_DATA:moneda::VARCHAR AS MONEDA,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:fecha_pedido::STRING
    ) AS FECHA_PEDIDO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'pedidos';


-- ============================================================
-- 9. DETALLE DE PEDIDOS
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_DETALLE_PEDIDOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:detalle_id::STRING)
        AS DETALLE_ID,
    TRY_TO_NUMBER(RECORD_DATA:pedido_id::STRING)
        AS PEDIDO_ID,
    TRY_TO_NUMBER(RECORD_DATA:producto_id::STRING)
        AS PRODUCTO_ID,
    TRY_TO_NUMBER(RECORD_DATA:cantidad::STRING)
        AS CANTIDAD,
    TRY_TO_DECIMAL(
        RECORD_DATA:precio_unitario::STRING, 14, 2
    ) AS PRECIO_UNITARIO,
    TRY_TO_DECIMAL(
        RECORD_DATA:costo_unitario::STRING, 14, 2
    ) AS COSTO_UNITARIO,
    TRY_TO_DECIMAL(
        RECORD_DATA:descuento::STRING, 14, 2
    ) AS DESCUENTO,
    TRY_TO_DECIMAL(
        RECORD_DATA:subtotal::STRING, 16, 2
    ) AS SUBTOTAL
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'detalle_pedidos';


-- ============================================================
-- 10. HISTORIAL DE PEDIDOS
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_HISTORIAL_PEDIDOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:historial_id::STRING)
        AS HISTORIAL_ID,
    TRY_TO_NUMBER(RECORD_DATA:pedido_id::STRING)
        AS PEDIDO_ID,
    RECORD_DATA:estado_anterior::VARCHAR
        AS ESTADO_ANTERIOR,
    RECORD_DATA:estado_nuevo::VARCHAR
        AS ESTADO_NUEVO,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:fecha_evento::STRING
    ) AS FECHA_EVENTO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'historial_pedidos';


-- ============================================================
-- 11. INVENTARIOS
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_INVENTARIOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:inventario_id::STRING)
        AS INVENTARIO_ID,
    TRY_TO_NUMBER(RECORD_DATA:producto_id::STRING)
        AS PRODUCTO_ID,
    TRY_TO_NUMBER(RECORD_DATA:ubicacion_id::STRING)
        AS UBICACION_ID,
    TRY_TO_NUMBER(RECORD_DATA:stock_fisico::STRING)
        AS STOCK_FISICO,
    TRY_TO_NUMBER(RECORD_DATA:stock_reservado::STRING)
        AS STOCK_RESERVADO,
    TRY_TO_NUMBER(RECORD_DATA:stock_disponible::STRING)
        AS STOCK_DISPONIBLE,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:actualizado_en::STRING
    ) AS ACTUALIZADO_EN
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'inventarios';


-- ============================================================
-- 12. RESERVAS DE INVENTARIO
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_RESERVAS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:reserva_id::STRING)
        AS RESERVA_ID,
    TRY_TO_NUMBER(RECORD_DATA:detalle_id::STRING)
        AS DETALLE_ID,
    TRY_TO_NUMBER(RECORD_DATA:inventario_id::STRING)
        AS INVENTARIO_ID,
    TRY_TO_NUMBER(RECORD_DATA:cantidad::STRING)
        AS CANTIDAD,
    RECORD_DATA:estado::VARCHAR AS ESTADO,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:fecha_reserva::STRING
    ) AS FECHA_RESERVA
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'reservas_inventario';


-- ============================================================
-- 13. MOVIMIENTOS DE INVENTARIO
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_MOVIMIENTOS AS
SELECT
    TRY_TO_NUMBER(RECORD_DATA:movimiento_id::STRING)
        AS MOVIMIENTO_ID,
    TRY_TO_NUMBER(RECORD_DATA:producto_id::STRING)
        AS PRODUCTO_ID,
    TRY_TO_NUMBER(RECORD_DATA:proveedor_id::STRING)
        AS PROVEEDOR_ID,
    TRY_TO_NUMBER(RECORD_DATA:pedido_id::STRING)
        AS PEDIDO_ID,
    TRY_TO_NUMBER(RECORD_DATA:dispositivo_id::STRING)
        AS DISPOSITIVO_ID,
    TRY_TO_NUMBER(
        RECORD_DATA:ubicacion_origen_id::STRING
    ) AS UBICACION_ORIGEN_ID,
    TRY_TO_NUMBER(
        RECORD_DATA:ubicacion_destino_id::STRING
    ) AS UBICACION_DESTINO_ID,
    RECORD_DATA:tipo_movimiento::VARCHAR
        AS TIPO_MOVIMIENTO,
    TRY_TO_NUMBER(RECORD_DATA:cantidad::STRING)
        AS CANTIDAD,
    RECORD_DATA:referencia_evento::VARCHAR
        AS REFERENCIA_EVENTO,
    TRY_TO_TIMESTAMP_TZ(
        RECORD_DATA:fecha_movimiento::STRING
    ) AS FECHA_MOVIMIENTO
FROM RAW.POSTGRES_RECORDS
WHERE SOURCE_TABLE = 'movimientos_inventario';


-- ============================================================
-- 14. EVENTOS IOT JSON
-- ============================================================

CREATE OR REPLACE VIEW STAGING.V_EVENTOS_IOT AS
SELECT
    EVENT_DATA:event_id::VARCHAR AS EVENT_ID,
    TRY_TO_NUMBER(EVENT_DATA:movement_id::STRING)
        AS MOVIMIENTO_ID,
    EVENT_DATA:event_type::VARCHAR AS TIPO_EVENTO,
    EVENT_DATA:classification::VARCHAR
        AS CLASIFICACION,
    EVENT_DATA:source::VARCHAR AS FUENTE,
    EVENT_DATA:device.code::VARCHAR
        AS CODIGO_DISPOSITIVO,
    EVENT_DATA:device.type::VARCHAR
        AS TIPO_DISPOSITIVO,
    EVENT_DATA:product.sku::VARCHAR
        AS SKU,
    TRY_TO_NUMBER(
        EVENT_DATA:product.quantity::STRING
    ) AS CANTIDAD,
    EVENT_DATA:warehouse::VARCHAR AS ALMACEN,
    EVENT_DATA:location.origin::VARCHAR
        AS UBICACION_ORIGEN,
    EVENT_DATA:location.destination::VARCHAR
        AS UBICACION_DESTINO,
    TRY_TO_NUMBER(EVENT_DATA:order_id::STRING)
        AS PEDIDO_ID,
    EVENT_DATA:status::VARCHAR AS ESTADO,
    TRY_TO_TIMESTAMP_TZ(
        EVENT_DATA:timestamp::STRING
    ) AS FECHA_EVENTO
FROM RAW.IOT_EVENTS;
