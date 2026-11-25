BEGIN;

CREATE SCHEMA IF NOT EXISTS operacion;

SET search_path TO operacion, public;

-- ==========================================
-- 1. CLIENTES
-- ==========================================

CREATE TABLE clientes (
    cliente_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    correo VARCHAR(150) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    ciudad VARCHAR(100),
    estado VARCHAR(100),
    pais VARCHAR(60) DEFAULT 'Mexico',
    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 2. CATEGORIAS
-- ==========================================

CREATE TABLE categorias (
    categoria_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT,
    activo BOOLEAN DEFAULT TRUE
);

-- ==========================================
-- 3. PRODUCTOS
-- ==========================================

CREATE TABLE productos (
    producto_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    categoria_id INTEGER NOT NULL REFERENCES categorias(categoria_id),
    sku VARCHAR(50) UNIQUE NOT NULL,
    codigo_barras VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT,
    marca VARCHAR(100),
    precio_venta NUMERIC(12,2) NOT NULL CHECK (precio_venta > 0),
    costo_unitario NUMERIC(12,2) NOT NULL CHECK (costo_unitario >= 0),
    stock_minimo INTEGER NOT NULL DEFAULT 10 CHECK (stock_minimo >= 0),
    activo BOOLEAN DEFAULT TRUE,
    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 4. PROVEEDORES
-- ==========================================

CREATE TABLE proveedores (
    proveedor_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    contacto VARCHAR(150),
    correo VARCHAR(150),
    telefono VARCHAR(20),
    ciudad VARCHAR(100),
    pais VARCHAR(60) DEFAULT 'Mexico',
    activo BOOLEAN DEFAULT TRUE
);


-- ==========================================
-- 5. ALMACENES
-- ==========================================

CREATE TABLE almacenes (
    almacen_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    ciudad VARCHAR(100),
    estado VARCHAR(100),
    capacidad_unidades INTEGER CHECK (capacidad_unidades > 0),
    activo BOOLEAN DEFAULT TRUE
);

-- ==========================================
-- 6. UBICACIONES
-- ==========================================

CREATE TABLE ubicaciones (
    ubicacion_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    almacen_id INTEGER NOT NULL REFERENCES almacenes(almacen_id),
    codigo VARCHAR(30) NOT NULL,
    zona VARCHAR(30) NOT NULL,
    pasillo VARCHAR(20),
    estante VARCHAR(20),
    nivel VARCHAR(20),
    capacidad INTEGER NOT NULL CHECK (capacidad > 0),
    activo BOOLEAN DEFAULT TRUE,
    UNIQUE (almacen_id, codigo)
);

-- ==========================================
-- 7. INVENTARIOS
-- ==========================================

CREATE TABLE inventarios (
    inventario_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    producto_id BIGINT NOT NULL REFERENCES productos(producto_id),
    ubicacion_id BIGINT NOT NULL REFERENCES ubicaciones(ubicacion_id),
    stock_fisico INTEGER NOT NULL DEFAULT 0,
    stock_reservado INTEGER NOT NULL DEFAULT 0,

    stock_disponible INTEGER GENERATED ALWAYS AS
        (stock_fisico - stock_reservado) STORED,

    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (stock_fisico >= 0),
    CHECK (stock_reservado >= 0),
    CHECK (stock_reservado <= stock_fisico),

    UNIQUE (producto_id, ubicacion_id)
);


-- ==========================================
-- 8. PEDIDOS
-- ==========================================

CREATE TABLE pedidos (
    pedido_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cliente_id BIGINT NOT NULL REFERENCES clientes(cliente_id),
    numero_pedido VARCHAR(40) UNIQUE NOT NULL,

    estado VARCHAR(25) NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN (
            'PENDIENTE',
            'CONFIRMADO',
            'EN_PREPARACION',
            'PREPARADO',
            'DESPACHADO',
            'ENTREGADO',
            'CANCELADO'
        )),

    metodo_pago VARCHAR(30),
    costo_envio NUMERIC(12,2) DEFAULT 0 CHECK (costo_envio >= 0),
    moneda CHAR(3) NOT NULL DEFAULT 'MXN',
    fecha_pedido TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 9. DETALLE DE PEDIDOS
-- ==========================================

CREATE TABLE detalle_pedidos (
    detalle_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id BIGINT NOT NULL REFERENCES pedidos(pedido_id),
    producto_id BIGINT NOT NULL REFERENCES productos(producto_id),

    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario > 0),
    costo_unitario NUMERIC(12,2) NOT NULL CHECK (costo_unitario >= 0),
    descuento NUMERIC(12,2) NOT NULL DEFAULT 0,

    subtotal NUMERIC(14,2) GENERATED ALWAYS AS
        ((cantidad * precio_unitario) - descuento) STORED,

    CHECK (descuento >= 0),
    CHECK (descuento <= cantidad * precio_unitario),

    UNIQUE (pedido_id, producto_id)
);

-- ==========================================
-- 10. HISTORIAL DE PEDIDOS
-- ==========================================

CREATE TABLE historial_pedidos (
    historial_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    pedido_id BIGINT NOT NULL REFERENCES pedidos(pedido_id),

    estado_anterior VARCHAR(25),

    estado_nuevo VARCHAR(25) NOT NULL
        CHECK (estado_nuevo IN (
            'PENDIENTE',
            'CONFIRMADO',
            'EN_PREPARACION',
            'PREPARADO',
            'DESPACHADO',
            'ENTREGADO',
            'CANCELADO'
        )),

    observaciones TEXT,
    fecha_evento TIMESTAMPTZ NOT NULL DEFAULT NOW()
);




-- ==========================================
-- 11. DISPOSITIVOS IOT
-- ==========================================

CREATE TABLE dispositivos_iot (
    dispositivo_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    almacen_id INTEGER NOT NULL REFERENCES almacenes(almacen_id),
    ubicacion_id BIGINT REFERENCES ubicaciones(ubicacion_id),

    codigo VARCHAR(40) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,

    tipo VARCHAR(30) NOT NULL CHECK (tipo IN (
        'RFID',
        'LECTOR_CODIGO_BARRAS'
    )),

    activo BOOLEAN DEFAULT TRUE,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==========================================
-- 12. MOVIMIENTOS DE INVENTARIO
-- ==========================================

CREATE TABLE movimientos_inventario (
    movimiento_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    producto_id BIGINT NOT NULL REFERENCES productos(producto_id),
    proveedor_id BIGINT REFERENCES proveedores(proveedor_id),
    pedido_id BIGINT REFERENCES pedidos(pedido_id),
    dispositivo_id BIGINT REFERENCES dispositivos_iot(dispositivo_id),

    ubicacion_origen_id BIGINT REFERENCES ubicaciones(ubicacion_id),
    ubicacion_destino_id BIGINT REFERENCES ubicaciones(ubicacion_id),

    tipo_movimiento VARCHAR(30) NOT NULL CHECK (
        tipo_movimiento IN (
            'RECEPCION',
            'UBICACION',
            'TRASLADO',
            'PICKING',
            'DESPACHO',
            'VERIFICACION',
            'DEVOLUCION'
        )
    ),

    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    referencia_evento VARCHAR(80) UNIQUE,
    observaciones TEXT,
    fecha_movimiento TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CHECK (
        ubicacion_origen_id IS NOT NULL
        OR ubicacion_destino_id IS NOT NULL
    ),

    CHECK (
        tipo_movimiento <> 'TRASLADO'
        OR (
            ubicacion_origen_id IS NOT NULL
            AND ubicacion_destino_id IS NOT NULL
            AND ubicacion_origen_id <> ubicacion_destino_id
        )
    ),

    CHECK (
        tipo_movimiento <> 'RECEPCION'
        OR ubicacion_destino_id IS NOT NULL
    ),

    CHECK (
        tipo_movimiento NOT IN ('PICKING', 'DESPACHO')
        OR (
            ubicacion_origen_id IS NOT NULL
            AND pedido_id IS NOT NULL
        )
    )
);









-- ==========================================
-- INDICES
-- ==========================================

CREATE INDEX idx_productos_categoria
    ON productos(categoria_id);

CREATE INDEX idx_pedidos_cliente
    ON pedidos(cliente_id);

CREATE INDEX idx_pedidos_fecha
    ON pedidos(fecha_pedido);

CREATE INDEX idx_pedidos_estado
    ON pedidos(estado);

CREATE INDEX idx_detalle_producto
    ON detalle_pedidos(producto_id);

CREATE INDEX idx_inventarios_ubicacion
    ON inventarios(ubicacion_id);

CREATE INDEX idx_movimientos_producto
    ON movimientos_inventario(producto_id);

CREATE INDEX idx_movimientos_fecha
    ON movimientos_inventario(fecha_movimiento);

CREATE INDEX idx_movimientos_pedido
    ON movimientos_inventario(pedido_id);

CREATE INDEX idx_historial_pedido_fecha
    ON historial_pedidos(pedido_id, fecha_evento);

CREATE INDEX idx_dispositivos_almacen
    ON dispositivos_iot(almacen_id);

COMMIT;