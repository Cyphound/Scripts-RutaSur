/*======================================================================*/
/* */
/* SCRIPT ETL PARA RUTA SUR S.A.                                        */
/* */
/* Ejecutar conectado como BGOMEZ. (BGOMEZ : OLAP - BGOMEZOLTP : OLTP)  */
/* */
/* Cambiar los nombres de los usuarios por los del OLTP y OLAP.         */
/* */
/*======================================================================*/

-- ====================================================================
-- ETAPA 0: LIMPIEZA DE TABLAS OLAP (TRUNCATE)
-- ====================================================================
TRUNCATE TABLE BGOMEZ.Bridge_Despacho_Carga;
TRUNCATE TABLE BGOMEZ.Bridge_Despacho_Trabajador;
TRUNCATE TABLE BGOMEZ.Fact_Despachos;
TRUNCATE TABLE BGOMEZ.Dim_Tiempo;
TRUNCATE TABLE BGOMEZ.Dim_Cliente;
TRUNCATE TABLE BGOMEZ.Dim_Vehiculo;
TRUNCATE TABLE BGOMEZ.Dim_Trabajador;
TRUNCATE TABLE BGOMEZ.Dim_Tipo_Trabajador;
TRUNCATE TABLE BGOMEZ.Dim_Tipo_Carga;
TRUNCATE TABLE BGOMEZ.Dim_Ruta;

-- ====================================================================
-- ETAPA 1: CARGA DE DIMENSIONES
-- ====================================================================

-- 1.1 Carga de Dim_Tiempo (Generación de fechas)
INSERT INTO BGOMEZ.Dim_Tiempo (Fecha_Completa, Anio, Mes_Numero, Mes_Nombre, Trimestre, Dia_Semana)
SELECT
    d.fecha,
    TO_NUMBER(TO_CHAR(d.fecha, 'YYYY')),
    TO_NUMBER(TO_CHAR(d.fecha, 'MM')),
    TO_CHAR(d.fecha, 'Month', 'NLS_DATE_LANGUAGE=Spanish'),
    TO_NUMBER(TO_CHAR(d.fecha, 'Q')),
    TO_CHAR(d.fecha, 'Day', 'NLS_DATE_LANGUAGE=Spanish')
FROM
    (
        SELECT TRUNC(SYSDATE) - ROWNUM + 1 AS fecha
        FROM DUAL CONNECT BY ROWNUM <= 365 * 5 -- Se genera 5 dias hacia atras
    ) d;
COMMIT;

-- 1.2 Carga de Dimensiones Simples

INSERT INTO BGOMEZ.Dim_Vehiculo (Patente_Vehiculo_OLTP, Tipo_Vehiculo, Modelo_Vehiculo, Capacidad_Toneladas)
SELECT PATENTE_VEHICULO, TIPO_VEHICULO, MODELO_VEHICULO, CAPACIDAD_TONELADA
FROM BGOMEZOLTP.VEHICULO;

INSERT INTO BGOMEZ.Dim_Tipo_Carga (Id_Tipo_Carga_OLTP, Nombre_Tipo_Carga)
SELECT ID_TIPO_CARGA, NOMBRE_TIPO_CARGA
FROM BGOMEZOLTP.TIPO_CARGA;

-- Dimensión manual
INSERT INTO BGOMEZ.Dim_Tipo_Trabajador (Nombre_Tipo_Trabajador) VALUES ('Conductor Principal');
INSERT INTO BGOMEZ.Dim_Tipo_Trabajador (Nombre_Tipo_Trabajador) VALUES ('Acompañante');
COMMIT;

-- 1.3 Carga de Dimensiones Compuestas (con transformaciones)

INSERT INTO BGOMEZ.Dim_Trabajador (Rut_Trabajador_OLTP, Nombre_Completo_Trabajador, Tipo_Licencia)
SELECT
    RUT_TRABAJADOR,
    NOMBRE_TRABAJADOR || ' ' || APELLIDO_TRABAJADOR,
    TIPO_LICENCIA
FROM BGOMEZOLTP.TRABAJADOR;

INSERT INTO BGOMEZ.Dim_Cliente (Id_Cliente_OLTP, Nombre_Cliente, Tipo_Cliente, Ciudad_Cliente, Region_Cliente)
SELECT
    c.ID_CLIENTE,
    c.NOMBRE_CLIENTE,
    c.TIPO_CLIENTE,
    p.CIUDAD_PUNTO,
    p.REGION_PUNTO
FROM BGOMEZOLTP.CLIENTE c
JOIN BGOMEZOLTP.PUNTO p ON c.ID_PUNTO = p.ID_PUNTO;

-- Carga de Dim_Ruta (Versión Mejorada)
INSERT INTO BGOMEZ.Dim_Ruta (
    Id_Ruta_Definida_OLTP, Nombre_Ruta, Distancia_Estimada_KM,
    Nombre_Centro_Origen, Ciudad_Origen, Region_Origen,
    Ciudad_Destino, Zona_Destino, Region_Destino,
    TIPO_DESTINO
)
SELECT
    rd.ID_RUTA,
    rd.NOMBRE_RUTA,
    rd.DISTANCIA_ESTIMADA_KM,
    cl_origen.NOMBRE_CENTRO,
    p_origen.CIUDAD_PUNTO,
    p_origen.REGION_PUNTO,
    p_destino.CIUDAD_PUNTO,
    p_destino.ZONA_PUNTO,
    p_destino.REGION_PUNTO,
    CASE
        WHEN c_destino.ID_CLIENTE IS NOT NULL THEN 'Cliente'
        WHEN cl_destino.ID_CENTRO IS NOT NULL THEN 'Centro de Distribucion'
        ELSE 'Desconocido'
END AS TIPO_DESTINO
FROM
    BGOMEZOLTP.RUTA_DEFINIDA rd
    JOIN BGOMEZOLTP.PUNTO p_origen ON rd.ID_PUNTO_ORIGEN = p_origen.ID_PUNTO
    JOIN BGOMEZOLTP.PUNTO p_destino ON rd.ID_PUNTO_DESTINO = p_destino.ID_PUNTO
    LEFT JOIN BGOMEZOLTP.CENTRO_LOGISTICO cl_origen ON p_origen.ID_PUNTO = cl_origen.ID_PUNTO
    LEFT JOIN BGOMEZOLTP.CENTRO_LOGISTICO cl_destino ON p_destino.ID_PUNTO = cl_destino.ID_PUNTO
    LEFT JOIN BGOMEZOLTP.CLIENTE c_destino ON p_destino.ID_PUNTO = c_destino.ID_PUNTO
COMMIT;

-- ====================================================================
-- ETAPA 2: CARGA DE LA TABLA DE HECHOS (Fact_Despachos)
-- ====================================================================
INSERT INTO BGOMEZ.Fact_Despachos (
    Tiempo_Key, Cliente_Key, Vehiculo_Key, Ruta_Key, Numero_Despacho_OLTP,
    Duracion_Estimada_Horas, Duracion_Real_Horas,
    Costo_Peaje_Estimado, Costo_Peaje_Real, Costo_Combustible_Real, Otros_Costos_Real, Costo_Total_Real
)
SELECT
    dt.Tiempo_Key,
    dc.Cliente_Key,
    dv.Vehiculo_Key,
    dr.Ruta_Key,
    d.ID_DESPACHO,
    -- Transformaciones
    rd.HORAS_ESTIMADAS,
    (d.FECHA_LLEGADA_REAL - d.FECHA_SALIDA_REAL) * 24, -- Diferencia de fechas da días, se multiplica por 24 para obtener horas
    rd.COSTO_PEAJE_ESTIMADO,
    d.COSTO_PEAJE_REAL,
    d.COSTO_COMBUSTIBLE_L,
    d.OTROS_COSTOS,
    (NVL(d.COSTO_PEAJE_REAL, 0) + NVL(d.COSTO_COMBUSTIBLE_L, 0) + NVL(d.OTROS_COSTOS, 0)) -- Calculo del costo total
FROM BGOMEZOLTP.DESPACHO d
-- Búsqueda de Keys (Lookups)
JOIN BGOMEZ.Dim_Tiempo dt ON dt.Fecha_Completa = TRUNC(d.FECHA_SALIDA_REAL)
JOIN BGOMEZ.Dim_Cliente dc ON dc.Id_Cliente_OLTP = d.ID_CLIENTE
JOIN BGOMEZ.Dim_Vehiculo dv ON dv.Patente_Vehiculo_OLTP = d.PATENTE_VEHICULO
JOIN BGOMEZOLTP.PERTENECE p_oltp ON d.ID_DESPACHO = p_oltp.ID_DESPACHO
JOIN BGOMEZ.Dim_Ruta dr ON p_oltp.ID_RUTA = dr.Id_Ruta_Definida_OLTP
JOIN BGOMEZOLTP.RUTA_DEFINIDA rd ON p_oltp.ID_RUTA = rd.ID_RUTA;
COMMIT;

-- ====================================================================
-- ETAPA 3: CARGA DE LAS TABLAS PUENTE (Bridge)
-- ====================================================================

-- 3.1 Carga de Bridge_Despacho_Trabajador
INSERT INTO BGOMEZ.Bridge_Despacho_Trabajador (Despacho_Key, Trabajador_Key, Tipo_Trabajador_Key)
SELECT
    f.Despacho_Key,
    dt.Trabajador_Key,
    dtt.Tipo_Trabajador_Key
FROM BGOMEZOLTP.REALIZA r_oltp
JOIN BGOMEZ.Fact_Despachos f ON r_oltp.ID_DESPACHO = f.Numero_Despacho_OLTP
JOIN BGOMEZ.Dim_Trabajador dt ON r_oltp.RUT_TRABAJADOR = dt.Rut_Trabajador_OLTP
JOIN BGOMEZOLTP.TRABAJADOR t_oltp ON r_oltp.RUT_TRABAJADOR = t_oltp.RUT_TRABAJADOR
JOIN BGOMEZ.Dim_Tipo_Trabajador dtt ON t_oltp.TIPO_TRABAJADOR = dtt.Nombre_Tipo_Trabajador;

-- 3.2 Carga de Bridge_Despacho_Carga
INSERT INTO BGOMEZ.Bridge_Despacho_Carga (Despacho_Key, Tipo_Carga_Key, Peso_Transportado_TN)
SELECT
    f.Despacho_Key,
    dtc.Tipo_Carga_Key,
    d_oltp.PESO_CARGA_TONELADAS
FROM BGOMEZOLTP.CLASIFICA_A c_oltp
JOIN BGOMEZ.Fact_Despachos f ON c_oltp.ID_DESPACHO = f.Numero_Despacho_OLTP
JOIN BGOMEZ.Dim_Tipo_Carga dtc ON c_oltp.ID_TIPO_CARGA = dtc.Id_Tipo_Carga_OLTP
JOIN BGOMEZOLTP.DESPACHO d_oltp ON c_oltp.ID_DESPACHO = d_oltp.ID_DESPACHO;
COMMIT;
