CREATE TABLE CPI_USA (
fecha DATE NOT NULL,
cpi_usa DECIMAL(13,4) NOT NULL,
CONSTRAINT PK_CPI_USA PRIMARY KEY (fecha)
);


SELECT * 
FROM CPI_USA
WHERE CPI_USA = 0
ORDER BY fecha DESC;

SELECT 
    COUNT(*)                    AS total_filas,
    MIN(Fecha)                  AS fecha_inicio,
    MAX(Fecha)                  AS fecha_fin,
    COUNT(*) - COUNT(CPI_USA)   AS nulls_detectados,
    SUM(CASE WHEN CPI_USA = 0 THEN 1 ELSE 0 END) AS ceros_detectados
FROM CPI_USA;

/* CPI_USA: falta octubre 2025   dato no publicado por FRED 
al momento de la descarga debido a interrupci n operativa.
Serie completa desde enero 2002 hasta septiembre 2025 
+ noviembre y diciembre 2025 */

DELETE FROM CPI_USA
WHERE CPI_USA = 0;


WITH var_men_dinamismo AS (
SELECT
fecha,
credito,
IMAE,
((IMAE - LAG(IMAE, 1) OVER(ORDER BY fecha))/(LAG(IMAE, 1) OVER(ORDER BY fecha)) * 100) AS var_men_imae,
((credito - LAG(credito, 1) OVER(ORDER BY fecha))/(LAG(credito, 1) OVER(ORDER BY fecha)) * 100) AS var_men_credito
FROM vw_macroeconomico
)
/* Procedemos con la creaci n de la vista con el calculo de la inflacion interanual de USA */
CREATE VIEW vw_inflacion_usa AS
WITH var_int_usa AS (
SELECT
fecha, 
CPI_USA,
((cpi_usa - LAG(cpi_usa, 12) OVER(ORDER BY fecha))/(LAG(cpi_usa, 12) OVER(ORDER BY fecha)) * 100) AS inflacion_interanual_usa
FROM CPI_USA
)
SELECT 
fecha,
cpi_usa,
inflacion_interanual_usa
FROM var_int_usa
WHERE inflacion_interanual_usa IS NOT NULL;

-- Documentaci n de proceso de BULK INSERT --
TRUNCATE TABLE CPI_USA;

BULK INSERT CPI_USA
FROM 'C:\Users\alvar\Downloads\CPIUSA2.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n'
);

/* Procedemos a modificar la vista de la tasa de colocaci n para optimizar consultas y de paso agregar inf. de USA */ 
ALTER VIEW vw_Tasa_Real_Colocacion AS
/* se mantiene el mismo m todo de pivoteo */
WITH tasas_por_plazo AS (
    SELECT 
        Fecha,
        moneda,
-- Hay que filtrar el tipo de tasa -- 
           MAX(CASE 
            WHEN Tipo_Tasa = 'Activa' AND Plazo = 'Corto Plazo' 
            THEN Tasa_Porcentaje 
        END) AS tasa_corto_plazo,
        MAX(CASE 
            WHEN Tipo_Tasa = 'Activa' AND Plazo = 'Largo Plazo' 
            THEN Tasa_Porcentaje 
        END) AS tasa_largo_plazo
    FROM Tasas_Interes_BCN
    GROUP BY Fecha, Moneda
),
-- Paso 2: traer inflaci n Nicaragua directo de tabla f sica --
-- Solo pedimos las dos columnas que necesitamos, nada m s -- 
inflacion_nic AS (
    SELECT 
        Fecha,
        inflacion_interanual
    FROM IPC
),
-- Paso 3: Procedemos a traer la inflaci n de USA desde su tabla --
inflacion_usa AS (
    SELECT 
        fecha,
        inflacion_interanual_usa
    FROM vw_inflacion_usa
)
-- Paso 4: unir todo y aplicar deflactor correcto seg n moneda -- 
SELECT
    tp.Fecha,
    tp.moneda,
    -- Para CP: si es MN resto inflaci n NI, si es ME resto inflaci n USA
    CASE 
        WHEN tp.moneda = 'MN' 
            THEN tp.tasa_corto_plazo - ni.inflacion_interanual
        WHEN tp.moneda = 'ME' 
            THEN tp.tasa_corto_plazo - usa.inflacion_interanual_usa
    END AS Tasa_real_Col_CP,

    -- Misma l gica para LP
    CASE 
        WHEN tp.moneda = 'MN' 
            THEN tp.tasa_largo_plazo - ni.inflacion_interanual
        WHEN tp.moneda = 'ME' 
            THEN tp.tasa_largo_plazo - usa.inflacion_interanual_usa
    END AS Tasa_real_Col_LP

FROM tasas_por_plazo AS tp

-- JOIN directo a tablas/vistas fuente para optimizar --
LEFT JOIN inflacion_nic  AS ni  ON tp.Fecha = ni.Fecha
LEFT  JOIN inflacion_usa  AS usa ON tp.Fecha = usa.fecha;

SELECT * 
FROM vw_Tasa_Real_Colocacion
ORDER BY fecha desc;


SELECT * FROM Tasas_Interes_BCN

SELECT fecha, Moneda, Plazo, Tasa_Porcentaje
FROM Tasas_Interes_BCN
WHERE Moneda = 'MN' 
AND Plazo = 'Largo Plazo'
AND fecha BETWEEN '2025-06-01' AND '2025-12-01'
ORDER BY fecha;

--Correr el siguiente query para saber que vistas necesitan una migraci n de tasas a BCN -*-
SELECT 
    v.name AS vista,
    m.definition
FROM sys.views v
JOIN sys.sql_modules m ON v.object_id = m.object_id
WHERE m.definition LIKE '%tasas_activas%';


/* Referencia para modificar spread bancario */
 ALTER VIEW vw_spread_bancario AS 
  WITH tasas_por_plazo AS (
SELECT 
 Fecha,
 moneda,
MAX(CASE 
            WHEN Tipo_Tasa = 'Activa' AND Plazo = 'Corto Plazo' 
            THEN Tasa_Porcentaje 
        END) AS tasa_corto_plazo,
        MAX(CASE 
            WHEN Tipo_Tasa = 'Activa' AND Plazo = 'Largo Plazo' 
            THEN Tasa_Porcentaje 
        END) AS tasa_largo_plazo
    FROM Tasas_Interes_BCN
    GROUP BY Fecha, Moneda
 )
SELECT
 tp.fecha,
 tp.moneda,
 (tp.tasa_corto_plazo - ti.tasa) AS spread_CP,
 (tp.tasa_largo_plazo - ti.tasa) AS spread_LP
 FROM tasas_por_plazo AS tp
 INNER JOIN tasa_interbancaria ti
 ON tp.fecha = ti.fecha
 AND tp.moneda = ti.moneda;

SELECT *
FROM vw_spread_bancario
ORDER BY fecha DESC

-- Proceso de creaci n de vista del TCR paso a paso --
CREATE VIEW vw_tipo_cambio_real AS
WITH base_nic AS (
     SELECT IPC AS base_val 
	 FROM IPC
	 WHERE fecha = '2011-01-01'
),
 base_usa AS (
     SELECT cpi_usa AS base_val
	 FROM CPI_USA
	 WHERE fecha = '2011-01-01'
)
SELECT
t.fecha,
t.tc,
i.IPC / bn.base_val * 100 AS ipc_nic_base2011,
c.cpi_usa / bu.base_val * 100 AS cpi_usa_base2011,
t.tc * (c.cpi_usa / bu.base_val)
      / (i.IPC / bn.base_val) AS TCR
FROM TC t
JOIN IPC i ON t.fecha = i.fecha
JOIN CPI_USA c ON t.fecha = c.fecha
CROSS JOIN base_nic bn
CROSS JOIN base_usa bu;

SELECT *
FROM vw_tipo_cambio_real

SELECT * FROM 
BM
ORDER BY fecha DESC

SELECT * 
FROM TC 
