BEGIN;

SET search_path TO operacion, public;

-- ==========================================
-- INICIAR PREPARACION DEL PEDIDO
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_iniciar_preparacion(
    p_pedido_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE operacion.pedidos
    SET estado = 'EN_PREPARACION'
    WHERE pedido_id = p_pedido_id
      AND estado = 'CONFIRMADO';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El pedido no existe o no esta confirmado';
    END IF;

END;
$$;




-- ==========================================
-- COMPLETAR PREPARACION Y PICKING
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_completar_preparacion(
    p_pedido_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR;
    v_reserva RECORD;
    v_dispositivo_id BIGINT;

BEGIN

    SELECT estado
    INTO v_estado
    FROM operacion.pedidos
    WHERE pedido_id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido inexistente';
    END IF;

    IF v_estado <> 'EN_PREPARACION' THEN
        RAISE EXCEPTION
            'El pedido debe estar en preparacion';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM operacion.reservas_inventario r
        JOIN operacion.detalle_pedidos d
            ON d.detalle_id = r.detalle_id
        WHERE d.pedido_id = p_pedido_id
          AND r.estado = 'ACTIVA'
    ) THEN
        RAISE EXCEPTION 'El pedido no tiene reservas activas';
    END IF;

    FOR v_reserva IN

        SELECT
            r.reserva_id,
            r.cantidad,
            i.producto_id,
            i.ubicacion_id,
            u.almacen_id
        FROM operacion.reservas_inventario r
        JOIN operacion.detalle_pedidos d
            ON d.detalle_id = r.detalle_id
        JOIN operacion.inventarios i
            ON i.inventario_id = r.inventario_id
        JOIN operacion.ubicaciones u
            ON u.ubicacion_id = i.ubicacion_id
        WHERE d.pedido_id = p_pedido_id
          AND r.estado = 'ACTIVA'
        ORDER BY r.reserva_id

    LOOP

        -- Seleccionar un dispositivo disponible
        SELECT dispositivo_id
        INTO v_dispositivo_id
        FROM operacion.dispositivos_iot
        WHERE almacen_id = v_reserva.almacen_id
          AND activo = TRUE
        ORDER BY
            CASE
                WHEN ubicacion_id = v_reserva.ubicacion_id
                THEN 0 ELSE 1
            END,
            dispositivo_id
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'No hay dispositivos activos en el almacen';
        END IF;

        -- Registrar movimiento PICKING
        INSERT INTO operacion.movimientos_inventario (
            producto_id,
            pedido_id,
            dispositivo_id,
            ubicacion_origen_id,
            tipo_movimiento,
            cantidad,
            referencia_evento,
            observaciones,
            fecha_movimiento
        )
        VALUES (
            v_reserva.producto_id,
            p_pedido_id,
            v_dispositivo_id,
            v_reserva.ubicacion_id,
            'PICKING',
            v_reserva.cantidad,
            'EVT-PICK-' || v_reserva.reserva_id,
            'Recoleccion de productos para pedido',
            clock_timestamp()
        );

    END LOOP;

    UPDATE operacion.pedidos
    SET estado = 'PREPARADO'
    WHERE pedido_id = p_pedido_id;

END;
$$;






-- ==========================================
-- DESPACHO DEL PEDIDO
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_despachar_pedido(
    p_pedido_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR;
    v_reserva RECORD;
    v_dispositivo_id BIGINT;

BEGIN

    SELECT estado
    INTO v_estado
    FROM operacion.pedidos
    WHERE pedido_id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido inexistente';
    END IF;

    IF v_estado <> 'PREPARADO' THEN
        RAISE EXCEPTION
            'El pedido debe estar preparado';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM operacion.reservas_inventario r
        JOIN operacion.detalle_pedidos d
            ON d.detalle_id = r.detalle_id
        WHERE d.pedido_id = p_pedido_id
          AND r.estado = 'ACTIVA'
    ) THEN
        RAISE EXCEPTION 'El pedido no tiene reservas activas';
    END IF;

    FOR v_reserva IN

        SELECT
            r.reserva_id,
            r.inventario_id,
            r.cantidad,
            i.producto_id,
            i.ubicacion_id,
            u.almacen_id
        FROM operacion.reservas_inventario r
        JOIN operacion.detalle_pedidos d
            ON d.detalle_id = r.detalle_id
        JOIN operacion.inventarios i
            ON i.inventario_id = r.inventario_id
        JOIN operacion.ubicaciones u
            ON u.ubicacion_id = i.ubicacion_id
        WHERE d.pedido_id = p_pedido_id
          AND r.estado = 'ACTIVA'
        ORDER BY i.producto_id, i.inventario_id
        FOR UPDATE OF r, i

    LOOP

        -- Actualizar existencias
        UPDATE operacion.inventarios
        SET
            stock_fisico =
                stock_fisico - v_reserva.cantidad,
            stock_reservado =
                stock_reservado - v_reserva.cantidad
        WHERE inventario_id = v_reserva.inventario_id
          AND stock_fisico >= v_reserva.cantidad
          AND stock_reservado >= v_reserva.cantidad;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Inconsistencia en el inventario reservado';
        END IF;

        -- Seleccionar dispositivo IoT
        SELECT dispositivo_id
        INTO v_dispositivo_id
        FROM operacion.dispositivos_iot
        WHERE almacen_id = v_reserva.almacen_id
          AND activo = TRUE
        ORDER BY
            CASE
                WHEN ubicacion_id = v_reserva.ubicacion_id
                THEN 0 ELSE 1
            END,
            dispositivo_id
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'No hay dispositivos activos en el almacen';
        END IF;

        -- Registrar salida de mercancia
        INSERT INTO operacion.movimientos_inventario (
            producto_id,
            pedido_id,
            dispositivo_id,
            ubicacion_origen_id,
            tipo_movimiento,
            cantidad,
            referencia_evento,
            observaciones,
            fecha_movimiento
        )
        VALUES (
            v_reserva.producto_id,
            p_pedido_id,
            v_dispositivo_id,
            v_reserva.ubicacion_id,
            'DESPACHO',
            v_reserva.cantidad,
            'EVT-DESP-' || v_reserva.reserva_id,
            'Salida de mercancia por pedido',
            clock_timestamp()
        );

        -- Actualizar reserva
        UPDATE operacion.reservas_inventario
        SET estado = 'CONSUMIDA'
        WHERE reserva_id = v_reserva.reserva_id;

    END LOOP;

    UPDATE operacion.pedidos
    SET estado = 'DESPACHADO'
    WHERE pedido_id = p_pedido_id;

END;
$$;




-- ==========================================
-- ENTREGA DEL PEDIDO
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_entregar_pedido(
    p_pedido_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE operacion.pedidos
    SET estado = 'ENTREGADO'
    WHERE pedido_id = p_pedido_id
      AND estado = 'DESPACHADO';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El pedido debe estar despachado';
    END IF;

END;
$$;

COMMIT;




SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'operacion'
ORDER BY routine_name;










