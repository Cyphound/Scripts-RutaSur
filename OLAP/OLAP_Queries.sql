/*
=================================================================================================
 SCRIPT DE CONSULTAS DE NEGOCIO SOBRE EL ESQUEMA OLAP (DATA WAREHOUSE)
=================================================================================================
 Propósito:
 Este script contiene las 6 consultas de negocio requeridas,
 adaptadas para ejecutarse sobre el modelo dimensional (esquema de estrella).
 Demuestra la simplicidad y eficiencia de las consultas en OLAP.
=================================================================================================
*/

-- ===============================================================================================
-- CONSULTA 1: ¿Cuál es el volumen total transportado por región de destino y tipo de carga?
-- ===============================================================================================

SELECT
    dr.Region_Destino,
    dtc.Nombre_Tipo_Carga,
    SUM(b_carga.Peso_Transportado_TN) AS Volumen_Total_Toneladas
FROM
    Fact_Despachos f
    JOIN Bridge_Despacho_Carga b_carga ON f.Despacho_Key = b_carga.Despacho_Key
    JOIN Dim_Tipo_Carga dtc ON b_carga.Tipo_Carga_Key = dtc.Tipo_Carga_Key
    JOIN Dim_Ruta dr ON f.Ruta_Key = dr.Ruta_Key
GROUP BY
    dr.Region_Destino,
    dtc.Nombre_Tipo_Carga
ORDER BY
    dr.Region_Destino,
    Volumen_Total_Toneladas DESC;


-- ===============================================================================================
-- CONSULTA 2: ¿Qué rendimiento (tiempo real vs. estimado) tienen los despachos por conductor y ruta?
-- ===============================================================================================

SELECT
    dt.Nombre_Completo_Trabajador AS Conductor,
    dr.Nombre_Ruta,
    AVG(f.Duracion_Estimada_Horas) AS Promedio_Horas_Estimadas,
    AVG(f.Duracion_Real_Horas) AS Promedio_Horas_Reales,
    AVG(f.Duracion_Real_Horas - f.Duracion_Estimada_Horas) AS Variacion_Promedio_Horas
FROM
    Fact_Despachos f
    JOIN Dim_Ruta dr ON f.Ruta_Key = dr.Ruta_Key
    JOIN Bridge_Despacho_Trabajador b_trab ON f.Despacho_Key = b_trab.Despacho_Key
    JOIN Dim_Trabajador dt ON b_trab.Trabajador_Key = dt.Trabajador_Key
    JOIN Dim_Tipo_Trabajador dtt ON b_trab.Tipo_Trabajador_Key = dtt.Tipo_Trabajador_Key
WHERE
    dtt.Nombre_Tipo_Trabajador = 'Conductor Principal'
GROUP BY
    dt.Nombre_Completo_Trabajador,
    dr.Nombre_Ruta
ORDER BY
    Conductor,
    Variacion_Promedio_Horas DESC;


-- ===============================================================================================
-- CONSULTA 3: ¿Qué vehículos están siendo subutilizados en cada mes?
-- ===============================================================================================

WITH UtilizacionMensualOLAP AS (
    SELECT
        f.Vehiculo_Key,
        dt.Anio,
        dt.Mes_Nombre,
        COUNT(DISTINCT f.Tiempo_Key) AS Dias_En_Despacho
    FROM
        Fact_Despachos f
        JOIN Dim_Tiempo dt ON f.Tiempo_Key = dt.Tiempo_Key
    GROUP BY
        f.Vehiculo_Key,
        dt.Anio,
        dt.Mes_Nombre
)
SELECT
    dv.Patente_Vehiculo_OLTP,
    dv.Tipo_Vehiculo,
    dv.Modelo_Vehiculo,
    u.Anio,
    u.Mes_Nombre,
    u.Dias_En_Despacho
FROM
    UtilizacionMensualOLAP u
    JOIN Dim_Vehiculo dv ON u.Vehiculo_Key = dv.Vehiculo_Key
WHERE
    u.Dias_En_Despacho < 5
ORDER BY
    u.Anio, u.Mes_Nombre, u.Dias_En_Despacho;


-- ===============================================================================================
-- CONSULTA 4: ¿Cuál es el costo logístico promedio por tonelada en cada centro de distribución?
-- ===============================================================================================

SELECT
    dr.Nombre_Centro_Origen AS Centro_Distribucion_Origen,
    SUM(f.Costo_Total_Real) AS Costo_Total_Logistico,
    SUM(bc.Peso_Transportado_TN) AS Total_Toneladas_Despachadas,
    CASE
        WHEN SUM(bc.Peso_Transportado_TN) > 0 THEN
             ROUND(SUM(f.Costo_Total_Real) / SUM(bc.Peso_Transportado_TN), 2)
        ELSE 0
    END AS Costo_Promedio_Por_Tonelada
FROM
    Fact_Despachos f
    JOIN Dim_Ruta dr ON f.Ruta_Key = dr.Ruta_Key
    JOIN Bridge_Despacho_Carga bc ON f.Despacho_Key = bc.Despacho_Key
WHERE
    dr.Nombre_Centro_Origen IS NOT NULL
GROUP BY
    dr.Nombre_Centro_Origen
ORDER BY
    Costo_Promedio_Por_Tonelada DESC;


-- ===============================================================================================
-- CONSULTA 5: Costo total de peajes a nivel mensual por tipo de despacho
-- ===============================================================================================

SELECT
    dt.Anio,
    dt.Mes_Nombre,
    dr.Tipo_Destino AS Tipo_Despacho,
    TO_CHAR(SUM(f.Costo_Peaje_Real)) AS Costo_Total_Peajes
FROM
    Fact_Despachos f
    JOIN Dim_Tiempo dt ON f.Tiempo_Key = dt.Tiempo_Key
    JOIN Dim_Ruta dr ON f.Ruta_Key = dr.Ruta_Key
WHERE
    f.Costo_Peaje_Real IS NOT NULL AND f.Costo_Peaje_Real > 0
GROUP BY
    dt.Anio,
    dt.Mes_Nombre,
    dr.Tipo_Destino
ORDER BY
    dt.Anio,
    MIN(dt.Fecha_Completa),
    Tipo_Despacho;


-- ===============================================================================================
-- CONSULTA 6: Resumen de rutas con mayor circulación a nivel mensual (Top 5)
-- ===============================================================================================

WITH RutasMensualesOLAP AS (
    SELECT
        f.Ruta_Key,
        dt.Anio,
        dt.Mes_Nombre,
        COUNT(f.Despacho_Key) AS Numero_De_Despachos,
        RANK() OVER (PARTITION BY dt.Anio, dt.Mes_Nombre ORDER BY COUNT(f.Despacho_Key) DESC) as Ranking_Ruta
    FROM
        Fact_Despachos f
        JOIN Dim_Tiempo dt ON f.Tiempo_Key = dt.Tiempo_Key
    GROUP BY
        f.Ruta_Key,
        dt.Anio,
        dt.Mes_Nombre
)
SELECT
    rm.Anio,
    rm.Mes_Nombre,
    rm.Ranking_Ruta,
    dr.Nombre_Ruta,
    dr.Ciudad_Origen AS Origen,
    dr.Ciudad_Destino AS Destino,
    rm.Numero_De_Despachos
FROM
    RutasMensualesOLAP rm
    JOIN Dim_Ruta dr ON rm.Ruta_Key = dr.Ruta_Key
WHERE
    rm.Ranking_Ruta <= 5
ORDER BY
    rm.Anio,
    rm.Mes_Nombre,
    rm.Ranking_Ruta;
