BEGIN;

SET search_path TO operacion, public;

-- ==========================================
-- ACTUALIZACION AUTOMATICA DE FECHAS
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_actualizar_fecha()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en := clock_timestamp();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_actualizar_clientes
BEFORE UPDATE ON clientes
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_actualizar_fecha();

CREATE TRIGGER trg_actualizar_productos
BEFORE UPDATE ON productos
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_actualizar_fecha();

CREATE TRIGGER trg_actualizar_inventarios
BEFORE UPDATE ON inventarios
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_actualizar_fecha();

CREATE TRIGGER trg_actualizar_pedidos
BEFORE UPDATE ON pedidos
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_actualizar_fecha();





-- ==========================================
-- HISTORIAL AUTOMATICO DE PEDIDOS
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_historial_pedido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        INSERT INTO operacion.historial_pedidos (
            pedido_id,
            estado_anterior,
            estado_nuevo,
            observaciones,
            fecha_evento
        )
        VALUES (
            NEW.pedido_id,
            NULL,
            NEW.estado,
            'Registro inicial del pedido',
            NEW.fecha_pedido
        );

    ELSIF OLD.estado IS DISTINCT FROM NEW.estado THEN

        INSERT INTO operacion.historial_pedidos (
            pedido_id,
            estado_anterior,
            estado_nuevo,
            observaciones
        )
        VALUES (
            NEW.pedido_id,
            OLD.estado,
            NEW.estado,
            'Cambio de estado del pedido'
        );

    END IF;

    RETURN NEW;

END;
$$;

CREATE TRIGGER trg_historial_pedidos
AFTER INSERT OR UPDATE OF estado ON pedidos
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_historial_pedido();






-- ==========================================
-- RECEPCION DE MERCANCIA
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_recepcion_mercancia(
    p_producto_id BIGINT,
    p_proveedor_id BIGINT,
    p_ubicacion_id BIGINT,
    p_cantidad INTEGER,
    p_dispositivo_id BIGINT DEFAULT NULL,
    p_referencia_evento VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_movimiento_id BIGINT;
    v_capacidad INTEGER;
    v_stock_total BIGINT;
    v_almacen_id INTEGER;

BEGIN

    -- Validar cantidad
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a cero';
    END IF;

    -- Validar producto
    IF NOT EXISTS (
        SELECT 1
        FROM operacion.productos
        WHERE producto_id = p_producto_id
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Producto inexistente o inactivo';
    END IF;

    -- Validar proveedor
    IF NOT EXISTS (
        SELECT 1
        FROM operacion.proveedores
        WHERE proveedor_id = p_proveedor_id
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Proveedor inexistente o inactivo';
    END IF;

    -- Validar y bloquear ubicacion
    SELECT capacidad, almacen_id
    INTO v_capacidad, v_almacen_id
    FROM operacion.ubicaciones
    WHERE ubicacion_id = p_ubicacion_id
      AND activo = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ubicacion inexistente o inactiva';
    END IF;

    -- Validar dispositivo, si fue proporcionado
    IF p_dispositivo_id IS NOT NULL THEN

        IF NOT EXISTS (
            SELECT 1
            FROM operacion.dispositivos_iot
            WHERE dispositivo_id = p_dispositivo_id
              AND almacen_id = v_almacen_id
              AND activo = TRUE
        ) THEN
            RAISE EXCEPTION 'Dispositivo IoT no valido';
        END IF;

    END IF;

    -- Comprobar capacidad de almacenamiento
    SELECT COALESCE(SUM(stock_fisico), 0)
    INTO v_stock_total
    FROM operacion.inventarios
    WHERE ubicacion_id = p_ubicacion_id;

    IF v_stock_total + p_cantidad > v_capacidad THEN
        RAISE EXCEPTION 'Capacidad de ubicacion excedida';
    END IF;

    -- Registrar movimiento de entrada
    INSERT INTO operacion.movimientos_inventario (
        producto_id,
        proveedor_id,
        dispositivo_id,
        ubicacion_destino_id,
        tipo_movimiento,
        cantidad,
        referencia_evento,
        observaciones
    )
    VALUES (
        p_producto_id,
        p_proveedor_id,
        p_dispositivo_id,
        p_ubicacion_id,
        'RECEPCION',
        p_cantidad,
        p_referencia_evento,
        'Recepcion de mercancia'
    )
    RETURNING movimiento_id INTO v_movimiento_id;

    -- Insertar o actualizar inventario
    INSERT INTO operacion.inventarios (
        producto_id,
        ubicacion_id,
        stock_fisico,
        stock_reservado
    )
    VALUES (
        p_producto_id,
        p_ubicacion_id,
        p_cantidad,
        0
    )
    ON CONFLICT (producto_id, ubicacion_id)
    DO UPDATE SET
        stock_fisico =
            inventarios.stock_fisico + EXCLUDED.stock_fisico;

    RETURN v_movimiento_id;

END;
$$;

COMMIT;






