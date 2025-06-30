/*
=================================================================================================
 SCRIPT DE CONSULTAS DE NEGOCIO SOBRE EL ESQUEMA OLTP
=================================================================================================
 Propósito:
 Este script contiene las 6 consultas de negocio requeridas,
 adaptadas para ejecutarse directamente sobre el modelo de datos transaccional (normalizado).
 Se utilizan para demostrar la complejidad de las consultas en OLTP en comparación con OLAP.
=================================================================================================
*/

-- ===============================================================================================
-- CONSULTA 1: ¿Cuál es el volumen total transportado por región de destino y tipo de carga?
-- ===============================================================================================

SELECT
    p_destino.REGION_PUNTO AS Region_Destino,
    tc.NOMBRE_TIPO_CARGA,
    SUM(d.PESO_CARGA_TONELADAS) AS Volumen_Total_Toneladas
FROM
    DESPACHO d
    JOIN CLASIFICA_A ca ON d.ID_DESPACHO = ca.ID_DESPACHO
    JOIN TIPO_CARGA tc ON ca.ID_TIPO_CARGA = tc.ID_TIPO_CARGA
    JOIN PERTENECE pe ON d.ID_DESPACHO = pe.ID_DESPACHO
    JOIN RUTA_DEFINIDA rd ON pe.ID_RUTA = rd.ID_RUTA
    JOIN PUNTO p_destino ON rd.ID_PUNTO_DESTINO = p_destino.ID_PUNTO
GROUP BY
    p_destino.REGION_PUNTO,
    tc.NOMBRE_TIPO_CARGA
ORDER BY
    Region_Destino,
    Volumen_Total_Toneladas DESC;


-- ===============================================================================================
-- CONSULTA 2: ¿Qué rendimiento (tiempo real vs. estimado) tienen los despachos por conductor y ruta?
-- ===============================================================================================

SELECT
    t.NOMBRE_TRABAJADOR || ' ' || t.APELLIDO_TRABAJADOR AS Conductor,
    rd.NOMBRE_RUTA,
    AVG(rd.HORAS_ESTIMADAS) AS Promedio_Horas_Estimadas,
    AVG((d.FECHA_LLEGADA_REAL - d.FECHA_SALIDA_REAL) * 24) AS Promedio_Horas_Reales,
    AVG(((d.FECHA_LLEGADA_REAL - d.FECHA_SALIDA_REAL) * 24) - rd.HORAS_ESTIMADAS) AS Variacion_Promedio_Horas
FROM
    DESPACHO d
    JOIN REALIZA r ON d.ID_DESPACHO = r.ID_DESPACHO
    JOIN TRABAJADOR t ON r.RUT_TRABAJADOR = t.RUT_TRABAJADOR
    JOIN PERTENECE p ON d.ID_DESPACHO = p.ID_DESPACHO
    JOIN RUTA_DEFINIDA rd ON p.ID_RUTA = rd.ID_RUTA
WHERE
    t.TIPO_TRABAJADOR = 'Conductor Principal'
GROUP BY
    t.NOMBRE_TRABAJADOR || ' ' || t.APELLIDO_TRABAJADOR,
    rd.NOMBRE_RUTA
ORDER BY
    Conductor,
    Variacion_Promedio_Horas DESC;


-- ===============================================================================================
-- CONSULTA 3: ¿Qué vehículos están siendo subutilizados en cada mes?
-- ===============================================================================================

WITH UtilizacionMensualOLTP AS (
    SELECT
        d.PATENTE_VEHICULO,
        TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY') AS Anio,
        TO_CHAR(d.FECHA_SALIDA_REAL, 'MM') AS Mes_Numero,
        TO_CHAR(d.FECHA_SALIDA_REAL, 'Month', 'NLS_DATE_LANGUAGE=Spanish') AS Mes_Nombre,
        COUNT(DISTINCT TRUNC(d.FECHA_SALIDA_REAL)) AS Dias_En_Despacho
    FROM
        DESPACHO d
    WHERE
        d.FECHA_SALIDA_REAL IS NOT NULL
    GROUP BY
        d.PATENTE_VEHICULO,
        TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY'),
        TO_CHAR(d.FECHA_SALIDA_REAL, 'MM'),
        TO_CHAR(d.FECHA_SALIDA_REAL, 'Month', 'NLS_DATE_LANGUAGE=Spanish')
)
SELECT
    u.Patente_Vehiculo,
    v.TIPO_VEHICULO,
    v.MODELO_VEHICULO,
    u.Anio,
    u.Mes_Nombre,
    u.Dias_En_Despacho
FROM
    UtilizacionMensualOLTP u
    JOIN VEHICULO v ON u.Patente_Vehiculo = v.PATENTE_VEHICULO
WHERE
    u.Dias_En_Despacho < 5
ORDER BY
    u.Anio, u.Mes_Numero, u.Dias_En_Despacho;


-- ===============================================================================================
-- CONSULTA 4: ¿Cuál es el costo logístico promedio por tonelada en cada centro de distribución?
-- ===============================================================================================

SELECT
    cl.NOMBRE_CENTRO AS Centro_Distribucion_Origen,
    SUM(NVL(d.COSTO_PEAJE_REAL, 0) + NVL(d.COSTO_COMBUSTIBLE_L, 0) + NVL(d.OTROS_COSTOS, 0)) AS Costo_Total_Logistico,
    SUM(d.PESO_CARGA_TONELADAS) AS Total_Toneladas_Despachadas,
    CASE
        WHEN SUM(d.PESO_CARGA_TONELADAS) > 0 THEN
             ROUND(SUM(NVL(d.COSTO_PEAJE_REAL, 0) + NVL(d.COSTO_COMBUSTIBLE_L, 0) + NVL(d.OTROS_COSTOS, 0)) / SUM(d.PESO_CARGA_TONELADAS), 2)
        ELSE 0
    END AS Costo_Promedio_Por_Tonelada
FROM
    DESPACHO d
    JOIN PERTENECE p ON d.ID_DESPACHO = p.ID_DESPACHO
    JOIN RUTA_DEFINIDA rd ON p.ID_RUTA = rd.ID_RUTA
    JOIN CENTRO_LOGISTICO cl ON rd.ID_PUNTO_ORIGEN = cl.ID_PUNTO
WHERE
    d.PESO_CARGA_TONELADAS IS NOT NULL
GROUP BY
    cl.NOMBRE_CENTRO
ORDER BY
    Costo_Promedio_Por_Tonelada DESC;


-- ===============================================================================================
-- CONSULTA 5: Costo total de peajes a nivel mensual por tipo de despacho
-- ===============================================================================================

SELECT
    TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY-Month', 'NLS_DATE_LANGUAGE=Spanish') AS Mes,
    CASE
        WHEN c_destino.ID_CLIENTE IS NOT NULL THEN 'Cliente Final'
        WHEN cl_destino.ID_CENTRO IS NOT NULL THEN 'Centro de Distribucion'
        ELSE 'Otro / No identificado'
    END AS Tipo_Despacho,
    TO_CHAR(SUM(d.COSTO_PEAJE_REAL)) AS Costo_Total_Peajes
FROM
    DESPACHO d
    JOIN PERTENECE p ON d.ID_DESPACHO = p.ID_DESPACHO
    JOIN RUTA_DEFINIDA rd ON p.ID_RUTA = rd.ID_RUTA
    LEFT JOIN CLIENTE c_destino ON rd.ID_PUNTO_DESTINO = c_destino.ID_PUNTO
    LEFT JOIN CENTRO_LOGISTICO cl_destino ON rd.ID_PUNTO_DESTINO = cl_destino.ID_PUNTO
WHERE
    d.FECHA_SALIDA_REAL IS NOT NULL
GROUP BY
    TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY-Month', 'NLS_DATE_LANGUAGE=Spanish'),
    TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYYMM'),
    CASE
        WHEN c_destino.ID_CLIENTE IS NOT NULL THEN 'Cliente Final'
        WHEN cl_destino.ID_CENTRO IS NOT NULL THEN 'Centro de Distribucion'
        ELSE 'Otro / No identificado'
    END
ORDER BY
    TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYYMM'),
    Tipo_Despacho;

-- ===============================================================================================
-- CONSULTA 6: Resumen de rutas con mayor circulación a nivel mensual (Top 5)
-- ===============================================================================================

WITH RutasMensualesOLTP AS (
    SELECT
        p.ID_RUTA,
        TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY-MM') AS Anio_Mes,
        COUNT(p.ID_DESPACHO) AS Numero_De_Despachos,
        RANK() OVER (PARTITION BY TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY-MM') ORDER BY COUNT(p.ID_DESPACHO) DESC) as Ranking_Ruta
    FROM
        PERTENECE p
        JOIN DESPACHO d ON p.ID_DESPACHO = d.ID_DESPACHO
    WHERE
        d.FECHA_SALIDA_REAL IS NOT NULL
    GROUP BY
        p.ID_RUTA,
        TO_CHAR(d.FECHA_SALIDA_REAL, 'YYYY-MM')
)
SELECT
    rm.Anio_Mes,
    rm.Ranking_Ruta,
    rd.NOMBRE_RUTA,
    p_origen.CIUDAD_PUNTO AS Origen,
    p_destino.CIUDAD_PUNTO AS Destino,
    rm.Numero_De_Despachos
FROM
    RutasMensualesOLTP rm
    JOIN RUTA_DEFINIDA rd ON rm.ID_RUTA = rd.ID_RUTA
    JOIN PUNTO p_origen ON rd.ID_PUNTO_ORIGEN = p_origen.ID_PUNTO
    JOIN PUNTO p_destino ON rd.ID_PUNTO_DESTINO = p_destino.ID_PUNTO
WHERE
    rm.Ranking_Ruta <= 5
ORDER BY
    rm.Anio_Mes,
    rm.Ranking_Ruta;
