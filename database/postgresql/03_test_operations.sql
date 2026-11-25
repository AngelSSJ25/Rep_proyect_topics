BEGIN;

SET search_path TO operacion, public;

-- Categoria de prueba
INSERT INTO categorias (nombre, descripcion)
VALUES ('Electronica', 'Productos electronicos de prueba');

-- Producto
INSERT INTO productos (
    categoria_id,
    sku,
    codigo_barras,
    nombre,
    precio_venta,
    costo_unitario
)
VALUES (
    (SELECT categoria_id FROM categorias
     WHERE nombre = 'Electronica'),
    'TEST-001',
    '7500000000001',
    'Audifonos inalambricos',
    599.00,
    350.00
);

-- Proveedor
INSERT INTO proveedores (nombre)
VALUES ('Proveedor de prueba');

-- Almacen
INSERT INTO almacenes (
    codigo,
    nombre,
    ciudad,
    capacidad_unidades
)
VALUES (
    'TEST-ALM',
    'Almacen de prueba',
    'Cancun',
    5000
);

-- Ubicacion
INSERT INTO ubicaciones (
    almacen_id,
    codigo,
    zona,
    pasillo,
    estante,
    nivel,
    capacidad
)
VALUES (
    (SELECT almacen_id FROM almacenes
     WHERE codigo = 'TEST-ALM'),
    'A-01',
    'A',
    '01',
    '01',
    '01',
    500
);

-- Dispositivo simulado
INSERT INTO dispositivos_iot (
    almacen_id,
    ubicacion_id,
    codigo,
    nombre,
    tipo
)
VALUES (
    (SELECT almacen_id FROM almacenes
     WHERE codigo = 'TEST-ALM'),
    (SELECT ubicacion_id FROM ubicaciones
     WHERE codigo = 'A-01'
       AND almacen_id = (
           SELECT almacen_id FROM almacenes
           WHERE codigo = 'TEST-ALM'
       )),
    'RFID-TEST-001',
    'Lector RFID de prueba',
    'RFID'
);

-- Simular recepcion de 100 unidades
SELECT operacion.fn_recepcion_mercancia(
    (SELECT producto_id FROM productos
     WHERE sku = 'TEST-001'),

    (SELECT proveedor_id FROM proveedores
     WHERE nombre = 'Proveedor de prueba'),

    (SELECT ubicacion_id FROM dispositivos_iot
     WHERE codigo = 'RFID-TEST-001'),

    100,

    (SELECT dispositivo_id FROM dispositivos_iot
     WHERE codigo = 'RFID-TEST-001'),

    'EVT-TEST-001'
) AS movimiento_generado;




INSERT INTO operacion.clientes (
    nombre,
    apellido,
    correo,
    ciudad,
    estado
)
VALUES (
    'Carlos',
    'Lopez',
    'cliente.prueba@example.com',
    'Cancun',
    'Quintana Roo'
);



SELECT operacion.fn_crear_pedido(
    (
        SELECT cliente_id
        FROM operacion.clientes
        WHERE correo = 'cliente.prueba@example.com'
    ),
    'PED-TEST-001',
    'TARJETA',
    50.00
) AS pedido_creado;






SELECT operacion.fn_agregar_producto(
    (
        SELECT pedido_id
        FROM operacion.pedidos
        WHERE numero_pedido = 'PED-TEST-001'
    ),
    (
        SELECT producto_id
        FROM operacion.productos
        WHERE sku = 'TEST-001'
    ),
    5,
    0
) AS detalle_creado;






SELECT operacion.fn_confirmar_pedido(
    (
        SELECT pedido_id
        FROM operacion.pedidos
        WHERE numero_pedido = 'PED-TEST-001'
    )
);






SELECT
    p.nombre,
    i.stock_fisico,
    i.stock_reservado,
    i.stock_disponible
FROM operacion.inventarios i
JOIN operacion.productos p
    ON p.producto_id = i.producto_id
WHERE p.sku = 'TEST-001';




SELECT
    p.numero_pedido,
    p.estado,
    d.cantidad,
    d.precio_unitario,
    d.subtotal
FROM operacion.pedidos p
JOIN operacion.detalle_pedidos d
    ON p.pedido_id = d.pedido_id
WHERE p.numero_pedido = 'PED-TEST-001';


SELECT *
FROM operacion.reservas_inventario;



SELECT
    p.numero_pedido,
    h.estado_anterior,
    h.estado_nuevo,
    h.fecha_evento
FROM operacion.historial_pedidos h
JOIN operacion.pedidos p
    ON p.pedido_id = h.pedido_id
WHERE p.numero_pedido = 'PED-TEST-001'
ORDER BY h.historial_id;




rollback;