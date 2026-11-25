BEGIN;

SET search_path TO operacion, public;

CREATE TABLE reservas_inventario (
    reserva_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    detalle_id BIGINT NOT NULL
        REFERENCES detalle_pedidos(detalle_id),

    inventario_id BIGINT NOT NULL
        REFERENCES inventarios(inventario_id),

    cantidad INTEGER NOT NULL CHECK (cantidad > 0),

    estado VARCHAR(20) NOT NULL DEFAULT 'ACTIVA'
        CHECK (estado IN (
            'ACTIVA',
            'CONSUMIDA',
            'LIBERADA'
        )),

    fecha_reserva TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (detalle_id, inventario_id)
);

CREATE INDEX idx_reservas_detalle
    ON reservas_inventario(detalle_id);

CREATE INDEX idx_reservas_inventario
    ON reservas_inventario(inventario_id);

CREATE TRIGGER trg_actualizar_reservas
BEFORE UPDATE ON reservas_inventario
FOR EACH ROW
EXECUTE FUNCTION operacion.fn_actualizar_fecha();





-- ==========================================
-- CREACION DE PEDIDOS
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_crear_pedido(
    p_cliente_id BIGINT,
    p_numero_pedido VARCHAR,
    p_metodo_pago VARCHAR DEFAULT 'TARJETA',
    p_costo_envio NUMERIC DEFAULT 0
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_pedido_id BIGINT;
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM operacion.clientes
        WHERE cliente_id = p_cliente_id
          AND activo = TRUE
    ) THEN
        RAISE EXCEPTION 'Cliente inexistente o inactivo';
    END IF;

    IF p_costo_envio IS NULL OR p_costo_envio < 0 THEN
        RAISE EXCEPTION 'Costo de envio incorrecto';
    END IF;

    INSERT INTO operacion.pedidos (
        cliente_id,
        numero_pedido,
        estado,
        metodo_pago,
        costo_envio
    )
    VALUES (
        p_cliente_id,
        p_numero_pedido,
        'PENDIENTE',
        p_metodo_pago,
        p_costo_envio
    )
    RETURNING pedido_id INTO v_pedido_id;

    RETURN v_pedido_id;

END;
$$;


-- ==========================================
-- AGREGAR PRODUCTOS AL PEDIDO
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_agregar_producto(
    p_pedido_id BIGINT,
    p_producto_id BIGINT,
    p_cantidad INTEGER,
    p_descuento NUMERIC DEFAULT 0
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR;
    v_precio NUMERIC;
    v_costo NUMERIC;
    v_detalle_id BIGINT;
BEGIN

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'Cantidad incorrecta';
    END IF;

    SELECT estado
    INTO v_estado
    FROM operacion.pedidos
    WHERE pedido_id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido inexistente';
    END IF;

    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION
            'Solo pueden modificarse pedidos pendientes';
    END IF;

    SELECT precio_venta, costo_unitario
    INTO v_precio, v_costo
    FROM operacion.productos
    WHERE producto_id = p_producto_id
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto inexistente o inactivo';
    END IF;

    IF p_descuento IS NULL
       OR p_descuento < 0
       OR p_descuento > p_cantidad * v_precio THEN
        RAISE EXCEPTION 'Descuento incorrecto';
    END IF;

    INSERT INTO operacion.detalle_pedidos (
        pedido_id,
        producto_id,
        cantidad,
        precio_unitario,
        costo_unitario,
        descuento
    )
    VALUES (
        p_pedido_id,
        p_producto_id,
        p_cantidad,
        v_precio,
        v_costo,
        p_descuento
    )
    RETURNING detalle_id INTO v_detalle_id;

    RETURN v_detalle_id;

END;
$$;




-- ==========================================
-- CONFIRMACION Y RESERVA DE PEDIDOS
-- ==========================================

CREATE OR REPLACE FUNCTION operacion.fn_confirmar_pedido(
    p_pedido_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado VARCHAR;
    v_detalle RECORD;
    v_inventario RECORD;
    v_pendiente INTEGER;
    v_reservar INTEGER;

BEGIN

    -- Validar y bloquear pedido
    SELECT estado
    INTO v_estado
    FROM operacion.pedidos
    WHERE pedido_id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido inexistente';
    END IF;

    IF v_estado <> 'PENDIENTE' THEN
        RAISE EXCEPTION
            'El pedido debe estar pendiente';
    END IF;

    -- Validar que existan productos
    IF NOT EXISTS (
        SELECT 1
        FROM operacion.detalle_pedidos
        WHERE pedido_id = p_pedido_id
    ) THEN
        RAISE EXCEPTION 'El pedido no contiene productos';
    END IF;

    -- Recorrer cada producto
    FOR v_detalle IN

        SELECT detalle_id, producto_id, cantidad
        FROM operacion.detalle_pedidos
        WHERE pedido_id = p_pedido_id
        ORDER BY producto_id

    LOOP

        v_pendiente := v_detalle.cantidad;

        -- Buscar existencias disponibles
        FOR v_inventario IN

            SELECT
                i.inventario_id,
                i.stock_disponible
            FROM operacion.inventarios i
            JOIN operacion.ubicaciones u
                ON u.ubicacion_id = i.ubicacion_id
            JOIN operacion.almacenes a
                ON a.almacen_id = u.almacen_id
            WHERE i.producto_id = v_detalle.producto_id
              AND i.stock_disponible > 0
              AND u.activo = TRUE
              AND a.activo = TRUE
            ORDER BY i.inventario_id
            FOR UPDATE OF i

        LOOP

            EXIT WHEN v_pendiente = 0;

            v_reservar := LEAST(
                v_pendiente,
                v_inventario.stock_disponible
            );

            -- Registrar unidades reservadas
            UPDATE operacion.inventarios
            SET stock_reservado =
                stock_reservado + v_reservar
            WHERE inventario_id =
                v_inventario.inventario_id;

            -- Asociar reserva con pedido
            INSERT INTO operacion.reservas_inventario (
                detalle_id,
                inventario_id,
                cantidad,
                estado
            )
            VALUES (
                v_detalle.detalle_id,
                v_inventario.inventario_id,
                v_reservar,
                'ACTIVA'
            );

            v_pendiente :=
                v_pendiente - v_reservar;

        END LOOP;

        -- Rechazar pedido si falta mercancía
        IF v_pendiente > 0 THEN

            RAISE EXCEPTION
                'Stock insuficiente para producto %. Faltan % unidades',
                v_detalle.producto_id,
                v_pendiente;

        END IF;

    END LOOP;

    -- Confirmar pedido
    UPDATE operacion.pedidos
    SET estado = 'CONFIRMADO'
    WHERE pedido_id = p_pedido_id;

END;
$$;

COMMIT;