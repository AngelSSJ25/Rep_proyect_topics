BEGIN;

SET search_path TO operacion, public;

-- ==========================================
-- CANCELACION DE PEDIDOS
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_cancelar_pedido(
    p_pedido_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR;
    v_reserva RECORD;

BEGIN

    SELECT estado
    INTO v_estado
    FROM operacion.pedidos
    WHERE pedido_id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido inexistente';
    END IF;

    IF v_estado NOT IN (
        'PENDIENTE',
        'CONFIRMADO',
        'EN_PREPARACION',
        'PREPARADO'
    ) THEN
        RAISE EXCEPTION
            'El pedido no puede cancelarse en su estado actual';
    END IF;

    -- Recuperar las reservas activas
    FOR v_reserva IN

        SELECT
            r.reserva_id,
            r.inventario_id,
            r.cantidad
        FROM operacion.reservas_inventario r
        JOIN operacion.detalle_pedidos d
            ON d.detalle_id = r.detalle_id
        JOIN operacion.inventarios i
            ON i.inventario_id = r.inventario_id
        WHERE d.pedido_id = p_pedido_id
          AND r.estado = 'ACTIVA'
        ORDER BY i.producto_id, i.inventario_id
        FOR UPDATE OF r, i

    LOOP

        -- Liberar las unidades reservadas
        UPDATE operacion.inventarios
        SET stock_reservado =
            stock_reservado - v_reserva.cantidad
        WHERE inventario_id = v_reserva.inventario_id
          AND stock_reservado >= v_reserva.cantidad;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Inconsistencia en el inventario reservado';
        END IF;

        UPDATE operacion.reservas_inventario
        SET estado = 'LIBERADA'
        WHERE reserva_id = v_reserva.reserva_id;

    END LOOP;

    UPDATE operacion.pedidos
    SET estado = 'CANCELADO'
    WHERE pedido_id = p_pedido_id;

END;
$$;



-- ==========================================
-- TRASLADO DE MERCANCIA
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_trasladar_mercancia(
    p_producto_id BIGINT,
    p_origen_id BIGINT,
    p_destino_id BIGINT,
    p_cantidad INTEGER,
    p_dispositivo_id BIGINT DEFAULT NULL,
    p_referencia_evento VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_origen RECORD;
    v_destino RECORD;
    v_stock_total BIGINT;
    v_movimiento_id BIGINT;

BEGIN

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'Cantidad incorrecta';
    END IF;

    IF p_origen_id IS NULL
       OR p_destino_id IS NULL
       OR p_origen_id = p_destino_id THEN
        RAISE EXCEPTION 'Ubicaciones incorrectas';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM operacion.productos
        WHERE producto_id = p_producto_id
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Producto inexistente o inactivo';
    END IF;

    -- Bloquear las ubicaciones en orden fijo
    PERFORM ubicacion_id
    FROM operacion.ubicaciones
    WHERE ubicacion_id IN (p_origen_id, p_destino_id)
    ORDER BY ubicacion_id
    FOR UPDATE;

    SELECT almacen_id
    INTO v_origen
    FROM operacion.ubicaciones
    WHERE ubicacion_id = p_origen_id
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ubicacion de origen no valida';
    END IF;

    SELECT almacen_id, capacidad
    INTO v_destino
    FROM operacion.ubicaciones
    WHERE ubicacion_id = p_destino_id
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ubicacion de destino no valida';
    END IF;

    IF v_origen.almacen_id <> v_destino.almacen_id THEN
        RAISE EXCEPTION
            'Solo se permiten traslados dentro del mismo almacen';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM operacion.almacenes
        WHERE almacen_id = v_origen.almacen_id
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Almacen inactivo';
    END IF;

    -- Validar dispositivo IoT
    IF p_dispositivo_id IS NOT NULL THEN

        IF NOT EXISTS (
            SELECT 1
            FROM operacion.dispositivos_iot
            WHERE dispositivo_id = p_dispositivo_id
              AND almacen_id = v_origen.almacen_id
              AND activo = TRUE
        ) THEN
            RAISE EXCEPTION 'Dispositivo IoT no valido';
        END IF;

    END IF;

    -- Bloquear inventarios involucrados
    PERFORM inventario_id
    FROM operacion.inventarios
    WHERE producto_id = p_producto_id
      AND ubicacion_id IN (p_origen_id, p_destino_id)
    ORDER BY inventario_id
    FOR UPDATE;

    -- Validar capacidad del destino
    SELECT COALESCE(SUM(stock_fisico), 0)
    INTO v_stock_total
    FROM operacion.inventarios
    WHERE ubicacion_id = p_destino_id;

    IF v_stock_total + p_cantidad > v_destino.capacidad THEN
        RAISE EXCEPTION 'Capacidad de destino excedida';
    END IF;

    -- Descontar mercancía del origen
    UPDATE operacion.inventarios
    SET stock_fisico = stock_fisico - p_cantidad
    WHERE producto_id = p_producto_id
      AND ubicacion_id = p_origen_id
      AND stock_disponible >= p_cantidad;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Stock disponible insuficiente';
    END IF;

    -- Agregar mercancía al destino
    INSERT INTO operacion.inventarios (
        producto_id,
        ubicacion_id,
        stock_fisico,
        stock_reservado
    )
    VALUES (
        p_producto_id,
        p_destino_id,
        p_cantidad,
        0
    )
    ON CONFLICT (producto_id, ubicacion_id)
    DO UPDATE SET
        stock_fisico =
            inventarios.stock_fisico + EXCLUDED.stock_fisico;

    -- Registrar movimiento
    INSERT INTO operacion.movimientos_inventario (
        producto_id,
        dispositivo_id,
        ubicacion_origen_id,
        ubicacion_destino_id,
        tipo_movimiento,
        cantidad,
        referencia_evento,
        observaciones
    )
    VALUES (
        p_producto_id,
        p_dispositivo_id,
        p_origen_id,
        p_destino_id,
        'TRASLADO',
        p_cantidad,
        p_referencia_evento,
        'Traslado interno de mercancia'
    )
    RETURNING movimiento_id INTO v_movimiento_id;

    RETURN v_movimiento_id;

END;
$$;


-- ==========================================
-- VALIDACION DE ESTADOS
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_validar_estado_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        IF NEW.estado <> 'PENDIENTE' THEN
            RAISE EXCEPTION
                'Un pedido nuevo debe iniciar como PENDIENTE';
        END IF;

        RETURN NEW;

    END IF;

    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    IF (
        (OLD.estado = 'PENDIENTE'
         AND NEW.estado IN ('CONFIRMADO', 'CANCELADO'))

        OR

        (OLD.estado = 'CONFIRMADO'
         AND NEW.estado IN ('EN_PREPARACION', 'CANCELADO'))

        OR

        (OLD.estado = 'EN_PREPARACION'
         AND NEW.estado IN ('PREPARADO', 'CANCELADO'))

        OR

        (OLD.estado = 'PREPARADO'
         AND NEW.estado IN ('DESPACHADO', 'CANCELADO'))

        OR

        (OLD.estado = 'DESPACHADO'
         AND NEW.estado = 'ENTREGADO')
    ) THEN

        RETURN NEW;

    END IF;

    RAISE EXCEPTION
        'Transicion de estado no permitida: % -> %',
        OLD.estado,
        NEW.estado;

END;
$$;

CREATE TRIGGER trg_validar_estado_pedido
BEFORE INSERT OR UPDATE OF estado
ON operacion.pedidos
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_validar_estado_pedido();


-- ==========================================
-- RELOJ PARA SIMULACION HISTORICA
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_fecha_operacion()
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha TEXT;
BEGIN

    v_fecha := current_setting(
        'smartstore.fecha_simulada',
        TRUE
    );

    IF v_fecha IS NOT NULL AND v_fecha <> '' THEN
        RETURN v_fecha::TIMESTAMPTZ;
    END IF;

    RETURN clock_timestamp();

END;
$$;

-- Actualizar la funcion de fechas existente

CREATE OR REPLACE FUNCTION operacion.fn_actualizar_fecha()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    NEW.actualizado_en := operacion.fn_fecha_operacion();

    RETURN NEW;

END;
$$;

-- Adaptar los valores predeterminados

ALTER TABLE operacion.clientes
    ALTER COLUMN fecha_registro
    SET DEFAULT operacion.fn_fecha_operacion(),
    ALTER COLUMN actualizado_en
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.productos
    ALTER COLUMN fecha_creacion
    SET DEFAULT operacion.fn_fecha_operacion(),
    ALTER COLUMN actualizado_en
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.pedidos
    ALTER COLUMN fecha_pedido
    SET DEFAULT operacion.fn_fecha_operacion(),
    ALTER COLUMN actualizado_en
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.inventarios
    ALTER COLUMN actualizado_en
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.historial_pedidos
    ALTER COLUMN fecha_evento
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.reservas_inventario
    ALTER COLUMN fecha_reserva
    SET DEFAULT operacion.fn_fecha_operacion(),
    ALTER COLUMN actualizado_en
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.movimientos_inventario
    ALTER COLUMN fecha_movimiento
    SET DEFAULT operacion.fn_fecha_operacion();

ALTER TABLE operacion.dispositivos_iot
    ALTER COLUMN fecha_registro
    SET DEFAULT operacion.fn_fecha_operacion();


-- Adaptar movimientos con fechas explicitas

CREATE OR REPLACE FUNCTION operacion.fn_fecha_movimiento()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF NULLIF(
        current_setting('smartstore.fecha_simulada', TRUE),
        ''
    ) IS NOT NULL THEN

        NEW.fecha_movimiento :=
            operacion.fn_fecha_operacion();

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_fecha_movimiento
BEFORE INSERT ON operacion.movimientos_inventario
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_fecha_movimiento();




-- ==========================================
-- CONTROL DE INTEGRIDAD DEL INVENTARIO
-- ==========================================

CREATE OR REPLACE VIEW operacion.v_integridad_inventario AS

WITH reservas_activas AS (

    SELECT
        inventario_id,
        SUM(cantidad) AS total_reservado
    FROM operacion.reservas_inventario
    WHERE estado = 'ACTIVA'
    GROUP BY inventario_id

)

SELECT
    i.inventario_id,
    p.sku,
    p.nombre AS producto,
    a.codigo AS almacen,
    u.codigo AS ubicacion,
    i.stock_fisico,
    i.stock_reservado,
    i.stock_disponible,

    COALESCE(r.total_reservado, 0)
        AS reservas_registradas,

    CASE

        WHEN i.stock_reservado <>
            COALESCE(r.total_reservado, 0)
        THEN 'INCONSISTENTE'

        WHEN i.stock_fisico < 0
        THEN 'INCONSISTENTE'

        WHEN i.stock_disponible < 0
        THEN 'INCONSISTENTE'

        ELSE 'CORRECTO'

    END AS estado_integridad

FROM operacion.inventarios i

JOIN operacion.productos p
    ON p.producto_id = i.producto_id

JOIN operacion.ubicaciones u
    ON u.ubicacion_id = i.ubicacion_id

JOIN operacion.almacenes a
    ON a.almacen_id = u.almacen_id

LEFT JOIN reservas_activas r
    ON r.inventario_id = i.inventario_id;


COMMIT;