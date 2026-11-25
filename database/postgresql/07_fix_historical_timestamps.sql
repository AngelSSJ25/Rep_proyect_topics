BEGIN;

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
            observaciones,
            fecha_evento
        )
        VALUES (
            NEW.pedido_id,
            OLD.estado,
            NEW.estado,
            'Cambio de estado del pedido',
            operacion.fn_fecha_operacion()
        );

    END IF;

    RETURN NEW;

END;
$$;

COMMIT;