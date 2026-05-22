SELECT * 
FROM BM

/* Proceso de creación de vista master */
SELECT i.fecha, b.Base_Monetaria, I.TasaPromedio, C.Credito, IM.IMAE, ipc.IPC, r.RIN, tc.TC, t.TRM
FROM inflacion AS i
LEFT JOIN BM AS B
ON i.fecha = b.fecha
LEFT JOIN credito AS c
ON i.fecha = c.fecha
LEFT JOIN IMAE AS im
ON i.Fecha = im.Fecha
LEFT JOIN IPC
ON i.fecha = ipc.fecha
LEFT JOIN RIN AS r
ON I.FECHA = r.fecha
LEFT JOIN TC 
ON i.fecha = tc.fecha
LEFT JOIN TRM AS t
ON i.fecha = t.fecha
 ORDER BY i.fecha

SELECT ta.fecha, ta.moneda, ta.plazo, ta.tasa, ti.moneda, ti.tasa
FROM tasas_Activas AS ta
LEFT JOIN tasa_interbancaria ti
ON ta.fecha = ti.fecha
ORDER BY ta.fecha DESC;


CREATE OR REPLACE VIEW vw_macroeconomico AS
SELECT i.fecha, b.Base_Monetaria, I.inflacion, C.Credito, IM.IMAE, ipc.IPC, r.RIN, tc.TC, t.TRM
FROM inflacion AS i
LEFT JOIN BM AS B
ON i.fecha = b.fecha
LEFT JOIN credito AS c
ON i.fecha = c.fecha
LEFT JOIN IMAE AS im
ON i.Fecha = im.Fecha
LEFT JOIN IPC
ON i.fecha = ipc.fecha
LEFT JOIN RIN AS r
ON I.FECHA = r.fecha
LEFT JOIN TC 
ON i.fecha = tc.fecha
LEFT JOIN TRM AS t
ON i.fecha = t.fecha;

ALTER VIEW vw_macroeconomico AS
SELECT 
    i.fecha, 
    b.Base_Monetaria, 
    C.Credito, 
    IM.IMAE, 
    i.IPC,
	i.inflacion_mensual,
	i.inflacion_interanual,
	i.inflacion_Acumulada,
    r.RIN, 
    tc.TC, 
    t.TRM
FROM IPC AS i
LEFT JOIN BM AS B ON i.fecha = b.fecha
LEFT JOIN credito AS c ON i.fecha = c.fecha
LEFT JOIN IMAE AS im ON i.Fecha = im.Fecha
LEFT JOIN RIN AS r ON I.FECHA = r.fecha
LEFT JOIN TC ON i.fecha = tc.fecha
LEFT JOIN TRM AS t ON i.fecha = t.fecha;


SELECT * FROM vw_macroeconomico

TRUNCATE TABLE BM

ALTER TABLE BM 
ADD M1   DECIMAL(18,4) NULL,
    M1A  DECIMAL(18,4) NULL,
    M2   DECIMAL(18,4) NULL,
    M2A  DECIMAL(18,4) NULL,
	M3   DECIMAL(18,4) NULL, 
	M3A  DECIMAL(18,4) NULL

SELECT * 
FROM BM


SELECT @@SERVERNAME

/*Comparación del promedio de inflación por año vs año más alto (2022)*/
WITH YearlyStats AS (
 SELECT
 YEAR(fecha) AS anio,
 AVG(inflacion_interanual) AS inflacion_promedio
 FROM IPC
 GROUP BY YEAR(fecha)
 )
SELECT 
anio,
inflacion_promedio,
inflacion_promedio - (
SELECT inflacion_promedio
FROM YearlyStats
WHERE anio = 2022) AS Gap_pico
FROM YearlyStats
ORDER BY anio ASC;


SELECT * FROM vw_macroeconomico

SELECT * FROM tasa_interbancaria;

/*Creación de view Spread Bancario*/
WITH tasas_por_plazo AS (
SELECT 
 Fecha,
 moneda, -- Se proceden a pivotear los row de tipo de tasa a columna utilizando agg y CASE WHEN -- 
 MAX(CASE WHEN plazo = 'Corto' THEN tasa END) AS tasa_corto_plazo,
 MAX(CASE WHEN plazo = 'Largo' THen tasa END) AS tasa_largo_plazo
 FROM tasas_activas
 GROUP BY fecha, moneda
 )
SELECT
 tp.fecha,
 tp.moneda,
 tasa_corto_plazo,
 tasa_largo_plazo,
 ti.tasa AS tasa_interbancaria
 FROM tasas_por_plazo AS tp
 INNER JOIN tasa_interbancaria ti
 ON tp.fecha = ti.fecha
 AND tp.moneda = ti.moneda
 ORDER BY fecha, moneda


 WITH tasas_por_plazo AS (
SELECT 
 Fecha,
 moneda,
 MAX(CASE WHEN plazo = 'Corto' THEN tasa END) AS tasa_corto_plazo,
 MAX(CASE WHEN plazo = 'Largo' THen tasa END) AS tasa_largo_plazo
 FROM tasas_activas
 GROUP BY fecha, moneda
 )
SELECT
 tp.fecha,
 tp.moneda,
 (tp.tasa_corto_plazo - ti.tasa) AS spread_CP,
 (tp.tasa_largo_plazo - ti.tasa) AS spread_LP
 FROM tasas_por_plazo AS tp
 INNER JOIN tasa_interbancaria ti
 ON tp.fecha = ti.fecha
 AND tp.moneda = ti.moneda
 ORDER BY fecha, moneda

 CREATE VIEW vw_spread_bancario AS 
  WITH tasas_por_plazo AS (
SELECT 
 Fecha,
 moneda,
 MAX(CASE WHEN plazo = 'Corto' THEN tasa END) AS tasa_corto_plazo,
 MAX(CASE WHEN plazo = 'Largo' THen tasa END) AS tasa_largo_plazo
 FROM tasas_activas
 GROUP BY fecha, moneda
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
 

 WITH tasas_por_plazo AS (
SELECT 
 Fecha,
 moneda,
 MAX(CASE WHEN plazo = 'Corto' THEN tasa END) AS tasa_corto_plazo,
 MAX(CASE WHEN plazo = 'Largo' THen tasa END) AS tasa_largo_plazo
 FROM tasas_activas
 GROUP BY fecha, moneda
 )
SELECT
 tp.fecha,
 tp.moneda,
 (tp.tasa_corto_plazo - ma.inflacion_interanual) AS Tasa_real_Col_CP,
 (tp.tasa_largo_plazo - ma.inflacion_interanual) AS Tasa_real_Col_LP
 FROM tasas_por_plazo AS tp
 INNER JOIN vw_macroeconomico AS ma
 ON tp.fecha = ma.fecha
 ORDER BY fecha, moneda

 /* Creamos la view para la tasa real de colocación */
CREATE VIEW vw_Tasa_Real_Colocacion AS 
 WITH tasas_por_plazo AS (
SELECT 
 Fecha,
 moneda,
 MAX(CASE WHEN plazo = 'Corto' THEN tasa END) AS tasa_corto_plazo,
 MAX(CASE WHEN plazo = 'Largo' THen tasa END) AS tasa_largo_plazo
 FROM tasas_activas
 GROUP BY fecha, moneda
 )
SELECT
 tp.fecha,
 tp.moneda,
 (tp.tasa_corto_plazo - ma.inflacion_interanual) AS Tasa_real_Col_CP,
 (tp.tasa_largo_plazo - ma.inflacion_interanual) AS Tasa_real_Col_LP
 FROM tasas_por_plazo AS tp
 INNER JOIN vw_macroeconomico AS ma
 ON tp.fecha = ma.fecha

SELECT 
    FORMAT(fecha, 'MMMM', 'es-ES') AS MesTexto, -- 'MMMM' para nombre completo, 'MMM' para abreviado
    moneda,
    tasa_real_col_cp,
    Tasa_real_Col_LP
FROM vw_Tasa_Real_Colocacion
WHERE YEAR(fecha) = 2022;


SELECT
fecha,
moneda,
spread_CP,
spread_LP,
LAG(spread_CP) OVER(PARTITION BY moneda ORDER BY fecha ASC) AS ultimo_spread_cp
FROM vw_spread_bancario
ORDER BY fecha ASC;

SELECT * FROM vw_macroeconomico


WITH var_men_dinamismo AS (
SELECT
fecha,
credito,
IMAE,
((IMAE - LAG(IMAE, 1) OVER(ORDER BY fecha))/(LAG(IMAE, 1) OVER(ORDER BY fecha)) * 100) AS var_men_imae,
((credito - LAG(credito, 1) OVER(ORDER BY fecha))/(LAG(credito, 1) OVER(ORDER BY fecha)) * 100) AS var_men_credito
FROM vw_macroeconomico
)
SELECT
v.fecha,
s.moneda,
v.var_men_imae,
v.var_men_credito,
s.spread_CP,
s.spread_LP
FROM var_men_dinamismo v
INNER JOIN vw_spread_bancario AS s
ON v.fecha = s.fecha
ORDER BY fecha DESC;


SELECT * FROM vw_spread_bancario

CREATE VIEW vw_dinamismo_real_financiero AS 
WITH var_men_dinamismo AS (
SELECT
fecha,
credito,
IMAE,
((IMAE - LAG(IMAE, 1) OVER(ORDER BY fecha))/(LAG(IMAE, 1) OVER(ORDER BY fecha)) * 100) AS var_men_imae,
((credito - LAG(credito, 1) OVER(ORDER BY fecha))/(LAG(credito, 1) OVER(ORDER BY fecha)) * 100) AS var_men_credito
FROM vw_macroeconomico
)
SELECT
v.fecha,
s.moneda,
v.var_men_imae,
v.var_men_credito,
s.spread_CP,
s.spread_LP
FROM var_men_dinamismo v
INNER JOIN vw_spread_bancario AS s
ON v.fecha = s.fecha
/* modificacion de view de dinamismo real financiero*/
ALTER VIEW vw_dinamismo_real_financiero AS 
WITH var_men_dinamismo AS (
SELECT
c.fecha,
c.credito,
i.IMAE,
((i.IMAE - LAG(i.IMAE, 1) OVER(ORDER BY c.fecha))/(LAG(i.IMAE, 1) OVER(ORDER BY c.fecha)) * 100) AS var_men_imae,
((credito - LAG(c.credito, 1) OVER(ORDER BY c.fecha))/(LAG(c.credito, 1) OVER(ORDER BY c.fecha)) * 100) AS var_men_credito
FROM credito c
INNER JOIN IMAE i
ON c.fecha = i.fecha
)
SELECT
v.fecha,
s.moneda,
v.var_men_imae,
v.var_men_credito,
s.spread_CP,
s.spread_LP
FROM var_men_dinamismo v
INNER JOIN vw_spread_bancario AS s
ON v.fecha = s.fecha
WHERE var_men_imae IS NOT NULL
AND var_men_credito IS NOT NULL




SELECT * FROM vw_dinamismo_real_financiero

SELECT *
FROM vw_macroeconomico

SELECT 
t.fecha,
t.trm,
ti.tasa
FROM TRM t
INNER JOIN tasa_interbancaria ti
ON t.fecha = ti.fecha
ORDER BY t.fecha DESC;


SELECT TOP 80 * 
FROM tasa_interbancaria
ORDER BY Fecha DESC

WITH unificacion_tasas AS (
 SELECT 
 t.fecha,
 ti.moneda,
 t.trm,
 ti.tasa
 FROM TRM t
 INNER JOIN tasa_interbancaria ti
 ON t.fecha = ti.fecha
 WHERE T.TRM IS NOT NULL
 )
 SELECT
 fecha,
 moneda,
 (tasa - trm) AS gap_transmision,
 (LAG(trm, 1) OVER(PARTITION BY moneda ORDER BY fecha)) AS TRM_mes_anterior,
 (CASE WHEN gap_transmision <= 0.5 THEN 'Transmisión Efectiva' ELSE 'Desvío de Política' END) AS efectividad
 FROM unificacion_tasas
 ORDER BY fecha ASC;


WITH unificacion_tasas AS (
 SELECT 
 t.fecha,
 ti.moneda,
 t.trm,
 ti.tasa
 FROM TRM t
 INNER JOIN tasa_interbancaria ti
 ON t.fecha = ti.fecha
 WHERE T.TRM IS NOT NULL
 ),
 calculo_gap AS (
 SELECT 
 fecha, 
 moneda,
 (tasa - trm) AS gap_transmision,
 (LAG(trm, 1) OVER(PARTITION BY moneda ORDER BY fecha)) AS TRM_mes_anterior
 FROM unificacion_tasas
 )
 SELECT TOP 80
 fecha, 
 moneda,
 gap_transmision,
 TRM_mes_anterior,
 CASE
      WHEN gap_transmision <= 0.5 THEN 'Transmisión Efectiva'
	  ELSE 'Desvío de Política' END AS Estado_Efectividad
 FROM calculo_gap
 WHERE TRM_mes_anterior IS NOT NULL
 ORDER BY fecha DESC;


SELECT * FROM vw_macroeconomico

WITH calculo_brecha_anclaje AS (
 SELECT 
 fecha, 
 inflacion_interanual,
 ((TC - LAG(TC, 12) OVER(ORDER BY fecha))/ LAG(TC, 12) OVER(ORDER BY fecha)) * 100 AS deslizamiento_anual
 FROM vw_macroeconomico
 )
SELECT 
fecha,
inflacion_interanual,
deslizamiento_anual
FROM calculo_brecha_anclaje
WHERE deslizamiento_anual IS NOT NULL 

CREATE VIEW vw_brecha_deslizamiento AS
WITH calculo_previo AS (
 SELECT 
 i.fecha, 
 i.inflacion_interanual,
 ((t.TC - LAG(t.TC, 12) OVER(ORDER BY i.fecha))/ LAG(t.TC, 12) OVER(ORDER BY i.fecha)) * 100 AS deslizamiento_anual
 FROM IPC i
 INNER JOIN TC t
 ON i.fecha = t.fecha
 ),
 calculo_deslizamiento_previo AS (
SELECT 
fecha,
inflacion_interanual,
deslizamiento_anual,
LAG(deslizamiento_anual, 1) OVER(ORDER BY fecha) AS deslizamiento_previo,
inflacion_interanual - deslizamiento_anual AS brecha_de_anclaje,
inflacion_interanual - deslizamiento_anual AS brecha_deslizamiento
FROM calculo_previo
WHERE deslizamiento_anual IS NOT NULL
)
SELECT
fecha,
inflacion_interanual,
deslizamiento_anual,
deslizamiento_previo,
brecha_deslizamiento,
CASE 
     WHEN brecha_deslizamiento <= 1.5 THEN 'Anclaje Exitoso'
	 WHEN brecha_deslizamiento > 1.5 AND brecha_deslizamiento <= 4 THEN 'Presión por Costos Importados'
	 WHEN brecha_deslizamiento > 4 THEN 'Desalineamiento / Shock Estructural'
	 END AS estado_anclaje_cambiario
FROM calculo_deslizamiento_previo
WHERE deslizamiento_previo IS NOT NULL

CREATE TABLE staging_tasas_bcn (
rowid INT IDENTITY (1,1),
fecha VARCHAR(100),
mn_pasiva_ahorro VARCHAR(50),
mn_pasiva_1m VARCHAR(50),
mn_pasiva_3m VARCHAR(50),
mn_pasiva_6m VARCHAR(50),
mn_pasiva_9m VARCHAR(50),
mn_pasiva_1y VARCHAR(50),
mn_pasiva_mas1y VARCHAR(50),
mn_activa_corto VARCHAR(50),
mn_activa_largo VARCHAR(50),
me_pasiva_ahorro VARCHAR(50),
me_pasiva_1m VARCHAR(50),
me_pasiva_3m VARCHAR(50),
me_pasiva_6m VARCHAR(50),
me_pasiva_9m VARCHAR(50),
me_pasiva_1y VARCHAR(50),
me_pasiva_mas1y VARCHAR(50),
me_activa_corto VARCHAR(50),
me_activa_largo VARCHAR(50)
);


SELECT * FROM staging_tasas_bcn
 


CREATE TABLE tasas_interes_BCN (
fecha DATE,
moneda NVARCHAR(10),
tipo_tasa NVARCHAR(20),
plazo NVARCHAR(50),
tasa_porcentaje FLOAT 
);

-- (Opcional) Limpia la tabla destino por si ya tenía datos de pruebas
TRUNCATE TABLE tasas_Interes_BCN;
GO

-- Inicia la línea de ensamblaje (Nota el punto y coma inicial)
;WITH Estacion_1_Categorizacion AS (
    SELECT 
        RowID,
        CASE WHEN LEN(TRIM(Fecha)) = 4 AND ISNUMERIC(TRIM(Fecha)) = 1 THEN TRIM(Fecha) ELSE NULL END AS Anio_Detectado,
        CASE WHEN LEN(TRIM(Fecha)) > 4 THEN TRIM(Fecha) ELSE NULL END AS Mes_Detectado,
        MN_Pasiva_Ahorro, MN_Pasiva_1m, MN_Pasiva_3m, MN_Pasiva_6m, MN_Pasiva_9m, mn_pasiva_1y, MN_Pasiva_Mas1y,
        MN_Activa_Corto, MN_Activa_Largo, ME_Pasiva_Ahorro, ME_Pasiva_1m, ME_Pasiva_3m, ME_Pasiva_6m,
        ME_Pasiva_9m, ME_Pasiva_1y, me_pasiva_mas1y, ME_Activa_Corto, ME_Activa_Largo
    FROM staging_tasas_bcn
    WHERE Fecha IS NOT NULL
),
Estacion_2_Agrupacion AS (
    SELECT *, COUNT(Anio_Detectado) OVER(ORDER BY RowID) AS grupo_anio FROM Estacion_1_Categorizacion
),
Estacion_3_FillDown AS (
    SELECT *, MAX(Anio_Detectado) OVER(PARTITION BY grupo_anio) AS anio_real FROM Estacion_2_Agrupacion
),
Estacion_4_Limpieza_Y_Fechas AS (
    SELECT *,
        CASE TRIM(Mes_Detectado)
            WHEN 'Enero'      THEN 1 WHEN 'Febrero'    THEN 2 WHEN 'Marzo'      THEN 3
            WHEN 'Abril'      THEN 4 WHEN 'Mayo'       THEN 5 WHEN 'Junio'      THEN 6
            WHEN 'Julio'      THEN 7 WHEN 'Agosto'     THEN 8 WHEN 'Septiembre' THEN 9
            WHEN 'Octubre'    THEN 10 WHEN 'Noviembre'  THEN 11 WHEN 'Diciembre'  THEN 12
        END AS Numero_Mes
    FROM Estacion_3_FillDown
    WHERE Mes_Detectado IS NOT NULL AND Mes_Detectado NOT LIKE '%Promedio%'
)

-- El INSERT va emparejado directamente con el SELECT final
INSERT INTO Tasas_Interes_BCN (Fecha, Moneda, Tipo_Tasa, Plazo, Tasa_Porcentaje)
SELECT 
    DATEFROMPARTS(CAST(anio_real AS INT), Numero_Mes, 1) AS Fecha, 
    v.moneda, v.tipo_tasa, v.plazo, CAST(v.tasa_string AS FLOAT) AS tasa_porcentaje
FROM Estacion_4_Limpieza_Y_Fechas f
CROSS APPLY (
    VALUES 
        ('MN', 'Pasiva', 'Ahorro',      f.MN_Pasiva_Ahorro),
        ('MN', 'Pasiva', '1 mes',       f.MN_Pasiva_1m),
        ('MN', 'Pasiva', '3 meses',     f.MN_Pasiva_3m),
        ('MN', 'Pasiva', '6 meses',     f.MN_Pasiva_6m),
        ('MN', 'Pasiva', '9 meses',     f.MN_Pasiva_9m),
        ('MN', 'Pasiva', '1 año',       f.mn_pasiva_1y),
        ('MN', 'Pasiva', 'Más de 1 año',f.MN_Pasiva_Mas1y),
        ('MN', 'Activa', 'Corto Plazo', f.MN_Activa_Corto),
        ('MN', 'Activa', 'Largo Plazo', f.MN_Activa_Largo),
        ('ME', 'Pasiva', 'Ahorro',      f.ME_Pasiva_Ahorro),
        ('ME', 'Pasiva', '1 mes',       f.ME_Pasiva_1m),
        ('ME', 'Pasiva', '3 meses',     f.ME_Pasiva_3m),
        ('ME', 'Pasiva', '6 meses',     f.ME_Pasiva_6m),
        ('ME', 'Pasiva', '9 meses',     f.ME_Pasiva_9m),
        ('ME', 'Pasiva', '1 año',       f.ME_Pasiva_1y),
        ('ME', 'Pasiva', 'Más de 1 año',f.me_pasiva_mas1y),
        ('ME', 'Activa', 'Corto Plazo', f.ME_Activa_Corto),
        ('ME', 'Activa', 'Largo Plazo', f.ME_Activa_Largo)
) AS v(moneda, tipo_tasa, plazo, tasa_string)
WHERE v.tasa_string IS NOT NULL AND TRIM(v.tasa_string) <> '' AND TRIM(v.tasa_string) <> '-';


SELECT * FROM tasas_interes_BCN
ORDER BY fecha desc

SELECT * FROM staging_tasas_bcn

-- Limpiamos la tabla destino
TRUNCATE TABLE Tasas_Interes_BCN;
GO

-- Inicia el ETL con la lógica corregida
;WITH Estacion_1_Categorizacion AS (
    SELECT 
        RowID,
        -- Lógica corregida: Si es un número, es el Año
        CASE WHEN ISNUMERIC(TRIM(Fecha)) = 1 THEN TRIM(Fecha) ELSE NULL END AS Anio_Detectado,
        
        -- Lógica corregida: Si NO es un número, es el Mes (o texto como "Promedio")
        CASE WHEN ISNUMERIC(TRIM(Fecha)) = 0 THEN TRIM(Fecha) ELSE NULL END AS Mes_Detectado,
        
        MN_Pasiva_Ahorro, MN_Pasiva_1m, MN_Pasiva_3m, MN_Pasiva_6m, MN_Pasiva_9m, mn_pasiva_1y, MN_Pasiva_Mas1y,
        MN_Activa_Corto, MN_Activa_Largo, ME_Pasiva_Ahorro, ME_Pasiva_1m, ME_Pasiva_3m, ME_Pasiva_6m,
        ME_Pasiva_9m, ME_Pasiva_1y, me_pasiva_mas1y, ME_Activa_Corto, ME_Activa_Largo
    FROM staging_tasas_bcn
    WHERE Fecha IS NOT NULL
),
Estacion_2_Agrupacion AS (
    SELECT *, COUNT(Anio_Detectado) OVER(ORDER BY RowID) AS grupo_anio FROM Estacion_1_Categorizacion
),
Estacion_3_FillDown AS (
    SELECT *, MAX(Anio_Detectado) OVER(PARTITION BY grupo_anio) AS anio_real FROM Estacion_2_Agrupacion
),
Estacion_4_Limpieza_Y_Fechas AS (
    SELECT *,
        CASE TRIM(Mes_Detectado)
            WHEN 'Enero'      THEN 1 WHEN 'Febrero'    THEN 2 WHEN 'Marzo'      THEN 3
            WHEN 'Abril'      THEN 4 WHEN 'Mayo'       THEN 5 WHEN 'Junio'      THEN 6
            WHEN 'Julio'      THEN 7 WHEN 'Agosto'     THEN 8 WHEN 'Septiembre' THEN 9
            WHEN 'Octubre'    THEN 10 WHEN 'Noviembre'  THEN 11 WHEN 'Diciembre'  THEN 12
        END AS Numero_Mes
    FROM Estacion_3_FillDown
    WHERE Mes_Detectado IS NOT NULL AND Mes_Detectado NOT LIKE '%Promedio%'
)

INSERT INTO Tasas_Interes_BCN (Fecha, Moneda, Tipo_Tasa, Plazo, Tasa_Porcentaje)
SELECT 
    DATEFROMPARTS(CAST(anio_real AS INT), Numero_Mes, 1) AS Fecha, 
    v.moneda, v.tipo_tasa, v.plazo, CAST(v.tasa_string AS FLOAT) AS tasa_porcentaje
FROM Estacion_4_Limpieza_Y_Fechas f
CROSS APPLY (
    VALUES 
        ('MN', 'Pasiva', 'Ahorro',      f.MN_Pasiva_Ahorro),
        ('MN', 'Pasiva', '1 mes',       f.MN_Pasiva_1m),
        ('MN', 'Pasiva', '3 meses',     f.MN_Pasiva_3m),
        ('MN', 'Pasiva', '6 meses',     f.MN_Pasiva_6m),
        ('MN', 'Pasiva', '9 meses',     f.MN_Pasiva_9m),
        ('MN', 'Pasiva', '1 año',       f.mn_pasiva_1y),
        ('MN', 'Pasiva', 'Más de 1 año',f.MN_Pasiva_Mas1y),
        ('MN', 'Activa', 'Corto Plazo', f.MN_Activa_Corto),
        ('MN', 'Activa', 'Largo Plazo', f.MN_Activa_Largo),
        ('ME', 'Pasiva', 'Ahorro',      f.ME_Pasiva_Ahorro),
        ('ME', 'Pasiva', '1 mes',       f.ME_Pasiva_1m),
        ('ME', 'Pasiva', '3 meses',     f.ME_Pasiva_3m),
        ('ME', 'Pasiva', '6 meses',     f.ME_Pasiva_6m),
        ('ME', 'Pasiva', '9 meses',     f.ME_Pasiva_9m),
        ('ME', 'Pasiva', '1 año',       f.ME_Pasiva_1y),
        ('ME', 'Pasiva', 'Más de 1 año',f.me_pasiva_mas1y),
        ('ME', 'Activa', 'Corto Plazo', f.ME_Activa_Corto),
        ('ME', 'Activa', 'Largo Plazo', f.ME_Activa_Largo)
) AS v(moneda, tipo_tasa, plazo, tasa_string)
WHERE v.tasa_string IS NOT NULL AND TRIM(v.tasa_string) <> '' AND TRIM(v.tasa_string) <> '-';

-- 1. Destruimos la tabla actual
DROP TABLE IF EXISTS Tasas_Interes_BCN;
GO

-- 2. La recreamos con la estructura y orden perfecto
CREATE TABLE Tasas_Interes_BCN (
    Fecha DATE,
    Moneda NVARCHAR(10),
    Tipo_Tasa NVARCHAR(20),
    Instrumento NVARCHAR(50),  -- ¡Aquí entra la nueva columna en su lugar lógico!
    Plazo NVARCHAR(50),
    Tasa_Porcentaje FLOAT
);
GO

TRUNCATE TABLE Tasas_Interes_BCN;
GO

;WITH Estacion_1_Categorizacion AS (
    SELECT 
        RowID,
        -- DEFENSA DE AÑO: Extraemos solo los 4 primeros caracteres y vemos si son un número
        CASE 
            WHEN LEN(TRIM(Fecha)) >= 4 AND ISNUMERIC(LEFT(TRIM(Fecha), 4)) = 1 
            THEN LEFT(TRIM(Fecha), 4) 
            ELSE NULL 
        END AS Anio_Detectado,
        
        -- DEFENSA DE MES: Si los primeros 4 NO son números, entonces es texto (Mes)
        CASE 
            WHEN LEN(TRIM(Fecha)) >= 4 AND ISNUMERIC(LEFT(TRIM(Fecha), 4)) = 0 
            THEN TRIM(Fecha) 
            ELSE NULL 
        END AS Mes_Detectado,
        
        MN_Pasiva_Ahorro, MN_Pasiva_1m, MN_Pasiva_3m, MN_Pasiva_6m, MN_Pasiva_9m, mn_pasiva_1y, MN_Pasiva_Mas1y,
        MN_Activa_Corto, MN_Activa_Largo, ME_Pasiva_Ahorro, ME_Pasiva_1m, ME_Pasiva_3m, ME_Pasiva_6m,
        ME_Pasiva_9m, ME_Pasiva_1y, me_pasiva_mas1y, ME_Activa_Corto, ME_Activa_Largo
    FROM staging_tasas_bcn
    WHERE Fecha IS NOT NULL
),
Estacion_2_Agrupacion AS (
    SELECT *, COUNT(Anio_Detectado) OVER(ORDER BY RowID) AS grupo_anio FROM Estacion_1_Categorizacion
),
Estacion_3_FillDown AS (
    SELECT *, MAX(Anio_Detectado) OVER(PARTITION BY grupo_anio) AS anio_real FROM Estacion_2_Agrupacion
),
Estacion_4_Limpieza_Y_Fechas AS (
    SELECT *,
        -- DEFENSA DE MES (LIKE): Usamos '%' para ignorar si el mes trae notas al pie como "Enero 1/" o "Enero*"
        CASE 
            WHEN Mes_Detectado LIKE 'Enero%'      THEN 1 
            WHEN Mes_Detectado LIKE 'Febrero%'    THEN 2 
            WHEN Mes_Detectado LIKE 'Marzo%'      THEN 3
            WHEN Mes_Detectado LIKE 'Abril%'      THEN 4 
            WHEN Mes_Detectado LIKE 'Mayo%'       THEN 5 
            WHEN Mes_Detectado LIKE 'Junio%'      THEN 6
            WHEN Mes_Detectado LIKE 'Julio%'      THEN 7 
            WHEN Mes_Detectado LIKE 'Agosto%'     THEN 8 
            WHEN Mes_Detectado LIKE 'Septiembre%' THEN 9
            WHEN Mes_Detectado LIKE 'Octubre%'    THEN 10 
            WHEN Mes_Detectado LIKE 'Noviembre%'  THEN 11 
            WHEN Mes_Detectado LIKE 'Diciembre%'  THEN 12
        END AS Numero_Mes
    FROM Estacion_3_FillDown
    WHERE Mes_Detectado IS NOT NULL AND Mes_Detectado NOT LIKE '%Promedio%'
)

INSERT INTO Tasas_Interes_BCN (Fecha, Moneda, Tipo_Tasa, Instrumento, Plazo, Tasa_Porcentaje)
SELECT 
    DATEFROMPARTS(CAST(anio_real AS INT), Numero_Mes, 1) AS Fecha, 
    v.moneda, v.tipo_tasa, v.instrumento, v.plazo, CAST(v.tasa_string AS FLOAT) AS tasa_porcentaje
FROM Estacion_4_Limpieza_Y_Fechas f
CROSS APPLY (
    VALUES 
        ('MN', 'Pasiva', 'Depósitos de ahorro',           'Sin plazo fijo',   f.MN_Pasiva_Ahorro),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '1 mes',        f.MN_Pasiva_1m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '3 meses',      f.MN_Pasiva_3m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '6 meses',      f.MN_Pasiva_6m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '9 meses',      f.MN_Pasiva_9m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '1 año',        f.mn_pasiva_1y),
        ('MN', 'Pasiva', 'Depósitos a Plazo', 'Más de 1 año', f.MN_Pasiva_Mas1y),
        ('MN', 'Activa', 'Préstamo',         'Corto Plazo',  f.MN_Activa_Corto),
        ('MN', 'Activa', 'Préstamo',         'Largo Plazo',  f.MN_Activa_Largo),
        ('ME', 'Pasiva', 'Depósitos de ahorro',           'Sin plazo fijo',   f.ME_Pasiva_Ahorro),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '1 mes',        f.ME_Pasiva_1m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '3 meses',      f.ME_Pasiva_3m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '6 meses',      f.ME_Pasiva_6m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '9 meses',      f.ME_Pasiva_9m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '1 año',        f.ME_Pasiva_1y),
        ('ME', 'Pasiva', 'Depósitos a Plazo', 'Más de 1 año', f.me_pasiva_mas1y),
        ('ME', 'Activa', 'Préstamo',         'Corto Plazo',  f.ME_Activa_Corto),
        ('ME', 'Activa', 'Préstamo',         'Largo Plazo',  f.ME_Activa_Largo)
) AS v(moneda, tipo_tasa, instrumento, plazo, tasa_string)
WHERE v.tasa_string IS NOT NULL AND TRIM(v.tasa_string) <> '' AND TRIM(v.tasa_string) <> '-';

SELECT * FROM Tasas_Interes_BCN

SELECT
    Moneda,
    Plazo,
    COUNT(*) AS cantidad_registros
FROM Tasas_Interes_BCN
GROUP BY 
    Moneda, 
    Plazo
ORDER BY 
    Plazo, 
    Moneda;


SELECT
COLUMN_NAME,
data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('fecha', 'moneda', 'tipo_tasa', 'instrumento', 'plazo', 'tasa_porcentaje')
AND table_name = 'tasas_interes_bcn';

CREATE VIEW vw_EstructuraPlazos_Spread	 AS
WITH separacion_plazos AS (
SELECT 
fecha, 
moneda,
SUM(CASE WHEN plazo = 'Corto Plazo' THEN tasa_porcentaje END) AS tasa_corto_plazo,
SUM(CASE WHEN plazo = 'Largo Plazo' THEN tasa_porcentaje END) AS tasa_largo_plazo
FROM Tasas_Interes_BCN
GROUP BY fecha, moneda
),
calculo_spread AS (
SELECT
fecha, 
moneda, 
tasa_largo_plazo - tasa_corto_plazo AS spread_plazos
FROM separacion_plazos
),
categorizacion_spread AS (
SELECT 
fecha,
moneda,
spread_plazos,
LAG(spread_plazos, 1) OVER(PARTITION BY moneda ORDER BY fecha) AS spread_mes_anterior,
CASE 
    WHEN spread_plazos > 0 THEN 'Curva normal'
	WHEN spread_plazos = 0 THEN 'Curva plana'
	WHEN spread_plazos < 0 THEN 'Curva invertida'
	END AS estado_spread
FROM calculo_spread
)
SELECT 
fecha, 
moneda,
spread_plazos,
spread_mes_anterior,
estado_spread
FROM categorizacion_spread
WHERE spread_mes_anterior IS NOT NULL;

SELECT * 
FROM vw_EstructuraPlazos_Spread

-- Estructura completa de todas las tablas
SELECT 
    t.name        AS tabla,
    c.column_id   AS orden,
    c.name        AS columna,
    tp.name       AS tipo_dato,
    c.max_length,
    c.is_nullable
FROM sys.tables t
JOIN sys.columns c  ON t.object_id = c.object_id
JOIN sys.types tp   ON c.user_type_id = tp.user_type_id
ORDER BY t.name, c.column_id


SELECT 
    fk.name AS fk_nombre,
    tp.name AS tabla_padre,
    cp.name AS columna_padre,
    tr.name AS tabla_hija,
    cr.name AS columna_hija
FROM sys.foreign_keys fk
JOIN sys.tables tp ON fk.referenced_object_id = tp.object_id
JOIN sys.tables tr ON fk.parent_object_id = tr.object_id
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns cp ON fkc.referenced_object_id = cp.object_id 
    AND fkc.referenced_column_id = cp.column_id
JOIN sys.columns cr ON fkc.parent_object_id = cr.object_id 
    AND fkc.parent_column_id = cr.column_id

-- Estructura de todas las VISTAS
SELECT 
    v.name        AS vista,
    c.column_id   AS orden,
    c.name        AS columna,
    tp.name       AS tipo_dato,
    c.max_length,
    c.is_nullable
FROM sys.views v
JOIN sys.columns c  ON v.object_id = c.object_id
JOIN sys.types tp   ON c.user_type_id = tp.user_type_id
ORDER BY v.name, c.column_id

SELECT * 
FROM Tasas_Interes_BCN
/*Proceso de limpieza de tabla consolidada de agregados monetarios desde archivo del BCN */

CREATE TABLE staging_agg_monetarios (
    RowID        INT IDENTITY(1,1) NOT NULL,  -- identificador de fila, se genera solo
    anio_mes     VARCHAR(50)  NULL,           -- "Enero", "2002", vacío, "Fuente:", etc.
    base_mon     VARCHAR(50)  NULL,           -- Base Monetaria como texto
    m1           VARCHAR(50)  NULL,           -- M1
    dep_spnf     VARCHAR(50)  NULL,           -- componente intermedio, no nos interesa
    m1a          VARCHAR(50)  NULL,           -- componente intermedio
    otras_oblig  VARCHAR(50)  NULL,           -- componente intermedio
    valores_bcn  VARCHAR(50)  NULL,           -- componente intermedio
    m2           VARCHAR(50)  NULL,           -- M2 
    otras_spnf   VARCHAR(50)  NULL,           -- componente intermedio
    m2a          VARCHAR(50)  NULL,           -- M3
    dep_nores    VARCHAR(50)  NULL,           -- componente intermedio
	m3           VARCHAR(50)  NULL,           -- M3 
    m3a          VARCHAR(50)  NULL            -- M3A
    -- las columnas vacías del final las ignoramos
);


BULK INSERT staging_agg_monetarios
FROM 'C:\Users\alvar\OneDrive\Documentos\Recursos Proyecto Macro\stagingaggmonetariosBCN.csv'
WITH (
    FIRSTROW = 1,          -- salta los 6 metadatos del inicio
    FIELDTERMINATOR = ';', -- delimitador punto y coma
    ROWTERMINATOR = '\n',  -- salto de línea Linux
    CODEPAGE = '1252'      -- Windows Western European / Latin-1
);

-- No funcionó. Se procede a insertar con el wizard -- 

-- Estación 1: Categorización entre mes y año --
WITH Estacion_1_Categorizacion AS (
    SELECT 
        RowID,
        -- DEFENSA DE AÑO: Extraemos solo los 4 primeros caracteres y vemos si son un número
        CASE 
            WHEN LEN(TRIM(Fecha)) >= 4 AND ISNUMERIC(LEFT(TRIM(Fecha), 4)) = 1 
            THEN LEFT(TRIM(Fecha), 4) 
            ELSE NULL 
        END AS Anio_Detectado,
        
        -- DEFENSA DE MES: Si los primeros 4 NO son números, entonces es texto (Mes)
        CASE 
            WHEN LEN(TRIM(Fecha)) >= 4 AND ISNUMERIC(LEFT(TRIM(Fecha), 4)) = 0 
            THEN TRIM(Fecha) 
            ELSE NULL 
        END AS Mes_Detectado,
        
        MN_Pasiva_Ahorro, MN_Pasiva_1m, MN_Pasiva_3m, MN_Pasiva_6m, MN_Pasiva_9m, mn_pasiva_1y, MN_Pasiva_Mas1y,
        MN_Activa_Corto, MN_Activa_Largo, ME_Pasiva_Ahorro, ME_Pasiva_1m, ME_Pasiva_3m, ME_Pasiva_6m,
        ME_Pasiva_9m, ME_Pasiva_1y, me_pasiva_mas1y, ME_Activa_Corto, ME_Activa_Largo
    FROM staging_tasas_bcn
    WHERE Fecha IS NOT NULL
),
Estacion_2_Agrupacion AS (
    SELECT *, COUNT(Anio_Detectado) OVER(ORDER BY RowID) AS grupo_anio FROM Estacion_1_Categorizacion
),
Estacion_3_FillDown AS (
    SELECT *, MAX(Anio_Detectado) OVER(PARTITION BY grupo_anio) AS anio_real FROM Estacion_2_Agrupacion
),
Estacion_4_Limpieza_Y_Fechas AS (
    SELECT *,
        -- DEFENSA DE MES (LIKE): Usamos '%' para ignorar si el mes trae notas al pie como "Enero 1/" o "Enero*"
        CASE 
            WHEN Mes_Detectado LIKE 'Enero%'      THEN 1 
            WHEN Mes_Detectado LIKE 'Febrero%'    THEN 2 
            WHEN Mes_Detectado LIKE 'Marzo%'      THEN 3
            WHEN Mes_Detectado LIKE 'Abril%'      THEN 4 
            WHEN Mes_Detectado LIKE 'Mayo%'       THEN 5 
            WHEN Mes_Detectado LIKE 'Junio%'      THEN 6
            WHEN Mes_Detectado LIKE 'Julio%'      THEN 7 
            WHEN Mes_Detectado LIKE 'Agosto%'     THEN 8 
            WHEN Mes_Detectado LIKE 'Septiembre%' THEN 9
            WHEN Mes_Detectado LIKE 'Octubre%'    THEN 10 
            WHEN Mes_Detectado LIKE 'Noviembre%'  THEN 11 
            WHEN Mes_Detectado LIKE 'Diciembre%'  THEN 12
        END AS Numero_Mes
    FROM Estacion_3_FillDown
    WHERE Mes_Detectado IS NOT NULL AND Mes_Detectado NOT LIKE '%Promedio%'
)

INSERT INTO Tasas_Interes_BCN (Fecha, Moneda, Tipo_Tasa, Instrumento, Plazo, Tasa_Porcentaje)
SELECT 
    DATEFROMPARTS(CAST(anio_real AS INT), Numero_Mes, 1) AS Fecha, 
    v.moneda, v.tipo_tasa, v.instrumento, v.plazo, CAST(v.tasa_string AS FLOAT) AS tasa_porcentaje
FROM Estacion_4_Limpieza_Y_Fechas f
CROSS APPLY (
    VALUES 
        ('MN', 'Pasiva', 'Depósitos de ahorro',           'Sin plazo fijo',   f.MN_Pasiva_Ahorro),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '1 mes',        f.MN_Pasiva_1m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '3 meses',      f.MN_Pasiva_3m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '6 meses',      f.MN_Pasiva_6m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '9 meses',      f.MN_Pasiva_9m),
        ('MN', 'Pasiva', 'Depósitos a Plazo', '1 año',        f.mn_pasiva_1y),
        ('MN', 'Pasiva', 'Depósitos a Plazo', 'Más de 1 año', f.MN_Pasiva_Mas1y),
        ('MN', 'Activa', 'Préstamo',         'Corto Plazo',  f.MN_Activa_Corto),
        ('MN', 'Activa', 'Préstamo',         'Largo Plazo',  f.MN_Activa_Largo),
        ('ME', 'Pasiva', 'Depósitos de ahorro',           'Sin plazo fijo',   f.ME_Pasiva_Ahorro),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '1 mes',        f.ME_Pasiva_1m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '3 meses',      f.ME_Pasiva_3m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '6 meses',      f.ME_Pasiva_6m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '9 meses',      f.ME_Pasiva_9m),
        ('ME', 'Pasiva', 'Depósitos a Plazo', '1 año',        f.ME_Pasiva_1y),
        ('ME', 'Pasiva', 'Depósitos a Plazo', 'Más de 1 año', f.me_pasiva_mas1y),
        ('ME', 'Activa', 'Préstamo',         'Corto Plazo',  f.ME_Activa_Corto),
        ('ME', 'Activa', 'Préstamo',         'Largo Plazo',  f.ME_Activa_Largo)
) AS v(moneda, tipo_tasa, instrumento, plazo, tasa_string)
WHERE v.tasa_string IS NOT NULL AND TRIM(v.tasa_string) <> '' AND TRIM(v.tasa_string) <> '-';


WITH estacion_1_categorizacion AS (
SELECT
   RowID,
   -- Aplicar defensa para los años -- 
CASE 
   WHEN LEN(TRIM(anio_mes)) >= 4 AND ISNUMERIC(LEFT(TRIM(anio_mes), 4)) = 1
   THEN LEFT(TRIM(anio_mes), 4)
   ELSE NULL
END AS anio_detectado,
CASE 
   WHEN LEN(TRIM(anio_mes)) >= 4 AND ISNUMERIC(LEFT(TRIM(anio_mes), 4 )) = 0 
   THEN TRIM(anio_mes)
   ELSE NULL
END AS mes_detectado,
base_mon, m1, dep_spnf, m1a, otras_oblig, valores_bcn, m2, otras_spnf, m2a, dep_nores, m3, m3a
FROM staging_agg_monetarios
WHERE anio_mes IS NOT NULL
), 
estacion_2_agrupacion AS (
SELECT *,
COUNT(anio_detectado) OVER(ORDER BY RowID) AS grupo_anio
FROM estacion_1_categorizacion
),
estacion_3_filldown AS (
SELECT *,
MAX(anio_detectado) OVER(PARTITION BY grupo_anio) AS anio_real
FROM estacion_2_agrupacion
), 
estacion_4_limpieza_y_fechas AS ( 
SELECT *,
 CASE 
            WHEN Mes_Detectado LIKE 'Enero%'      THEN 1 
            WHEN Mes_Detectado LIKE 'Febrero%'    THEN 2 
            WHEN Mes_Detectado LIKE 'Marzo%'      THEN 3
            WHEN Mes_Detectado LIKE 'Abril%'      THEN 4 
            WHEN Mes_Detectado LIKE 'Mayo%'       THEN 5 
            WHEN Mes_Detectado LIKE 'Junio%'      THEN 6
            WHEN Mes_Detectado LIKE 'Julio%'      THEN 7 
            WHEN Mes_Detectado LIKE 'Agosto%'     THEN 8 
            WHEN Mes_Detectado LIKE 'Septiembre%' THEN 9
            WHEN Mes_Detectado LIKE 'Octubre%'    THEN 10 
            WHEN Mes_Detectado LIKE 'Noviembre%'  THEN 11 
            WHEN Mes_Detectado LIKE 'Diciembre%'  THEN 12
        END AS Numero_Mes
	FROM estacion_3_filldown
	WHERE Mes_Detectado IS NOT NULL AND Mes_Detectado NOT LIKE '%Promedio%'
),
estacion_5_columnas_limpias AS (
SELECT 
-- construimos fechas con valores ya calculados 
    DATEFROMPARTS(CAST(anio_real AS INT), numero_mes, 1)  AS fecha, 
	 -- Función de limpieza numérica reutilizable para cada columna:
        -- Paso 1: TRIM elimina espacios al inicio y final
        -- Paso 2: REPLACE quita la coma de miles (4,235.40 ? 4235.40)
        -- Paso 3: REPLACE quita paréntesis de negativos
        -- Paso 4: CAST convierte el texto limpio a decimal
        -- Paso 5: el CASE detecta si era negativo y multiplica por -1
		CASE 
		   WHEN  TRIM(base_mon) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(base_mon),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE TRY_CAST(REPLACE(REPLACE(TRIM(base_mon), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS base_monetaria,
        CASE 
		   WHEN  TRIM(m1) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m1),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m1), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS M1,
         CASE 
		   WHEN  TRIM(m1a) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m1a),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m1a), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS M1A,
          CASE 
		   WHEN  TRIM(m2) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * CAST(REPLACE(REPLACE(REPLACE(TRIM(m2),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE CAST(REPLACE(REPLACE(TRIM(m2), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS M2,
          CASE 
		   WHEN  TRIM(m2a) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m2a),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m2a), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS M2A,
           CASE 
		   WHEN  TRIM(m3) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m3),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m3), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS M3,
           CASE 
		   WHEN  TRIM(m3a) LIKE '(%)'  --Manera de denotar valores negativos entre paréntesis
           THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m3a),',',''),'(',''),')','') AS DECIMAL(18,4))
           ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m3a), ',', ''), ' ', '') AS DECIMAL(18,4))
   END AS M3A
   FROM estacion_4_limpieza_y_fechas
    -- Filtramos filas sin número de mes válido (años, vacías, metadatos del final)
    WHERE numero_mes IS NOT NULL
)
/*Se procede con el insert en la tabla BM previamente modificada */
INSERT INTO BM (fecha, Base_Monetaria, M1, M1A, M2, M2A, M3, M3A)
SELECT 
     fecha,
	 base_monetaria,
	 m1,
	 m1a,
	 m2,
	 m2a,
	 m3,
	 m3a
FROM estacion_5_columnas_limpias
ORDER BY fecha;

SELECT * 
FROM BM





   -- Después de crear el staging y hacer BULK INSERT, ejecutá esto
SELECT TOP 20 RowID, anio_mes, base_mon, m1, m1a, m2, m2a, m3, m3a
FROM staging_agg_monetarios
ORDER BY RowID;

SELECT * 
FROM Tasas_Interes_BCN
/*Procedemos con la creación de view relacionada al ratio de dolarización */
CREATE VIEW vw_exposicion_externa AS
SELECT
    b.fecha,
	b.m2a,
	b.m3a,
    -- Monto absoluto en ME: depósitos fuera de M2 dentro de M3
	(b.M3a - b.M2a) AS depositos_no_residentes,
    -- Ratio de dolarización con protección doble contra NULL y cero
	CAST((M3a - M2a) / NULLIF(M3a, 0) AS DECIMAL(18,4)) AS ratio_exposicion_externa,
	CAST((M3a - M2a) * 100 / NULLIF(M3a, 0) AS DECIMAL(18,4)) AS ratio_exposicion_externa_pct
FROM BM b
WHERE M3A IS NOT NULL  -- filtramos filas sin M3 (pre-2007 meses sin dato)
AND M2A IS NOT NULL;




SELECT * FROM vw_exposicion_externa
ORDER BY fecha desc;

/*Procedemos a crear vista crowding_out_sp */
ALTER VIEW crowding_out_spnf AS
WITH calculo_base AS (
SELECT 
   b.fecha, 
   b.M2,
   b.M2A,
  -- Usamos M2A - M2 para un SPNF más limpio según fuente 4-15
   b.M2A - b.M2 AS liquidez_spnf,
   c.credito,
-- Peso del estado en la liquidez total (M3A)
CAST((b.M2A - b.M2) AS DECIMAL(18,6)) / NULLIF(b.M3A, 0) AS peso_estado
FROM BM b
INNER JOIN credito c
ON b.fecha = c.fecha
),
variaciones_interanuales AS (
SELECT
    fecha, 
	peso_estado,
--Calculamos la variación interanual del crédito --
	((credito - LAG(credito, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(credito, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_inter_credito,
-- Calculamos la variación interanual de la liquidez del spnf --
    ((liquidez_spnf - LAG(liquidez_spnf, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(liquidez_spnf, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_inter_spnf
FROM calculo_base
)
SELECT 
    fecha,
    peso_estado,
    var_inter_credito,
    var_inter_spnf
FROM variaciones_interanuales
WHERE var_inter_spnf IS NOT NULL 
AND var_inter_credito IS NOT NULL;
/* En la view anterior la VAR interanual de credito se corta debido al IS NOT NULL, al hacer el calculo de la VAR INT del SPNF. 
Se creará una medida con los valores completos en Power BI */

)
SELECT * 
FROM variaciones_interanuales
WHERE growth_credito IS NOT NULL AND growth_spnf IS NOT NULL
ORDER BY fecha ASC;

/* Procedemos a calcular el ratio de cobertura de RIN sobre agregados monetarios */
ALTER VIEW vw_cobertura_res_agregados_monetarios AS
WITH conversion_RIN AS (
SELECT 
--Iniciamos convirtiendo las RIN a córdobas según el TC del mes --
r.fecha,
r.rin AS RIN_USD,
r.rin * t.tc AS conv_RIN_cor
FROM RIN r
--Inner Join para matches mas limpios --
INNER JOIN TC t 
ON r.fecha = t.fecha
),
ratio_cobertura AS (
SELECT
c.fecha,
--Se dividen RIN convertidas entre cada M y se formatea para que entregue decimales y que el denom sea NUll si este es 0 -- 
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.base_monetaria, 0) AS cobertura_rin_BM,
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.M1, 0) AS cobertura_rin_m1,
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.M1a, 0) AS cobertura_rin_m1a,
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.M2, 0) AS cobertura_rin_m2,
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.M2a, 0) AS cobertura_rin_m2a,
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.M3, 0) AS cobertura_rin_m3,
CAST((c.conv_RIN_cor) AS DECIMAL(18,6)) / NULLIF(b.M3a, 0) AS cobertura_rin_m3a
FROM conversion_RIN c
INNER JOIN BM b
ON c.Fecha = b.Fecha
),
comparacion_int AS (
SELECT 
fecha,
cobertura_rin_BM,
((cobertura_rin_BM - LAG(cobertura_rin_BM, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_BM, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_BM,
cobertura_rin_m1,
--Se aplica un LAG para obtener la variación interanual de cada mes --
((cobertura_rin_m1 - LAG(cobertura_rin_m1, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_m1, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_m1,
cobertura_rin_m1a,
((cobertura_rin_m1a - LAG(cobertura_rin_m1a, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_m1a, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_m1a,
cobertura_rin_m2,
((cobertura_rin_m2 - LAG(cobertura_rin_m2, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_m2, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_m2,
cobertura_rin_m2a,
((cobertura_rin_m2a - LAG(cobertura_rin_m2a, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_m2a, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_m2a,
cobertura_rin_m3,
((cobertura_rin_m3 - LAG(cobertura_rin_m3, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_m3, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_m3,
cobertura_rin_m3a,
((cobertura_rin_m3a - LAG(cobertura_rin_m3a, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(cobertura_rin_m3a, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_int_cobertura_rin_m3a
FROM ratio_cobertura
)
SELECT
-- Se mandan a traer todas las coberturas y variaciones por M --
     fecha,
	 cobertura_rin_BM,
	 var_int_cobertura_rin_BM,
	 cobertura_rin_m1,
     var_int_cobertura_rin_m1,
	 cobertura_rin_m1a,
     var_int_cobertura_rin_m1a,
	 cobertura_rin_m2,
     var_int_cobertura_rin_m2,
     cobertura_rin_m2a,
     var_int_cobertura_rin_m2a,
	 cobertura_rin_m3,
     var_int_cobertura_rin_m3,
	 cobertura_rin_m3a,
     var_int_cobertura_rin_m3a
FROM comparacion_int
WHERE var_int_cobertura_rin_m1 IS NOT NULL;


WITH pivoteo_moneda AS (
SELECT 
    Fecha,
    plazo, -- Se proceden a pivotear los row de tipo de tasa a columna utilizando agg y CASE WHEN -- 
    MAX(CASE WHEN Moneda = 'MN' THEN Tasa_Porcentaje END) AS tasa_MN,
    MAX(CASE WHEN Moneda = 'ME' THen Tasa_Porcentaje END) AS tasa_ME
FROM Tasas_Interes_BCN t
WHERE tipo_tasa = 'Activa'
GROUP BY fecha, Plazo
),
calculo_tasa_real AS (
SELECT
p.fecha, 
p.plazo,
CAST(p.tasa_MN - i.inflacion_interanual AS DECIMAL(18,4)) AS tasa_real_MN,
CAST(p.tasa_ME - iu.inflacion_interanual_usa AS DECIMAL(18,4)) AS tasa_real_ME
FROM pivoteo_moneda p
INNER JOIN IPC I
ON p.fecha = i.fecha
INNER JOIN vw_inflacion_usa iu
ON p.fecha = iu.fecha
)
SELECT
fecha,
plazo,
tasa_real_MN,
tasa_real_ME
FROM calculo_tasa_real
WHERE tasa_real_MN IS NOT NULL 
AND tasa_real_ME IS NOT NULL;

CREATE VIEW vw_paridad_real_de_tasas AS
WITH pivoteo_moneda AS (
SELECT 
    Fecha,
	tipo_tasa, --para clasificar entre distintos plazos pasivos --
    plazo, -- Se proceden a pivotear los row de tipo de tasa a columna utilizando agg y CASE WHEN -- 
    MAX(CASE WHEN Moneda = 'MN' THEN Tasa_Porcentaje END) AS tasa_MN,
    MAX(CASE WHEN Moneda = 'ME' THen Tasa_Porcentaje END) AS tasa_ME
FROM Tasas_Interes_BCN t
GROUP BY fecha, Tipo_Tasa, Plazo
),
calculo_tasa_real AS (
SELECT
p.fecha,
p.tipo_tasa,
p.plazo,
p.tasa_MN - i.inflacion_interanual_calculada AS tasa_real_MN,
p.tasa_ME - iu.inflacion_interanual_usa AS tasa_real_ME
FROM pivoteo_moneda p
INNER JOIN IPC I
ON p.fecha = i.fecha
INNER JOIN vw_inflacion_usa iu
ON p.fecha = iu.fecha
)
SELECT
fecha,
Tipo_Tasa,
plazo,
tasa_real_MN,
tasa_real_ME,
tasa_real_MN - tasa_real_ME AS spread_paridad_tasas
FROM calculo_tasa_real
WHERE tasa_real_MN IS NOT NULL 
AND tasa_real_ME IS NOT NULL;



--Se procede a crear una nueva columna en tabla IPC para tener inflación interanual con decimales mas precisos--
ALTER TABLE IPC
ADD inflacion_calculada DECIMAL(18, 6)

UPDATE IPC
SET inflacion_calculada = COALESCE(, inflacion_interanual);
-- 2. Consolidamos y actualizamos en un solo movimiento
WITH CTE_Calculo AS (
    SELECT 
        fecha,
        -- Realizamos la aritmética directamente aquí
        ((IPC - LAG(IPC, 12) OVER(ORDER BY fecha)) / NULLIF(LAG(IPC, 12) OVER(ORDER BY fecha), 0) * 100) AS calculada_temp,
        inflacion_interanual AS oficial_original
    FROM IPC
)
UPDATE T
SET T.inflacion_calculada = COALESCE(C.calculada_temp, C.oficial_original)
FROM IPC T
JOIN CTE_Calculo C ON T.fecha = C.fecha;


SELECT * 
FROM Tasas_Interes_BCN
ORDER BY fecha


SELECT *
FROM vw_paridad_real_de_tasas
select * 
FROm vw_Tasa_Real_Colocacion
order by FECHA

-- Se proceden a borrar valores inconsistentes de tasa_interbancaria-- 
DELETE FROM tasa_interbancaria
WHERE Fecha = '1899-12-30';

/*se ´procede a crear una columna en formato decimal de la var int del IMAE */

SELECT 
     fecha,
	 IMAE,
	 ((IMAE - LAG(IMAE, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(IMAE, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_inter_IMAE
FROM IMAE



SELECT *,
        ((credito - LAG(credito, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(credito, 12) OVER (ORDER BY fecha), 0)) * 100 AS var_inter_credito
FROM credito
ORDER BY fecha DESC;

SELECT * 
FROM RIN


-- Se procede a agregar columna con las RIN en córdobas a la tabla física -- 
ALTER TABLE dbo.RIN
ADD RIN_NIO decimal(14,6) NULL;

UPDATE r
SET r.RIN_NIO = CAST(r.RIN * t.tc AS decimal(14,6))
FROM RIN AS r
INNER JOIN  TC AS t
ON r.Fecha = t.Fecha

SELECT * 
FROM BM 
ORDER BY fecha desc;

SELECT * 
FROM vw_cobertura_res_agregados_monetarios
ORDER BY fecha desc

-- Protegemos fecha de la tabla BM para el proceso de creación de procedimiento almacenado para actualizar datos --

ALTER TABLE BM
ADD CONSTRAINT UQ_BM_Fecha UNIQUE (fecha);


-- Se hace backup y se elimina la tabla staging --
SELECT *
INTO dbo.staging_agg_monetarios_backup
FROM dbo.staging_agg_monetarios;

DROP TABLE dbo.staging_agg_monetarios;
--Procedemos a crear una nueva tabla de staging pero con row_id que venga del archivo --
CREATE TABLE dbo.staging_agg_monetarios (
    source_row_id INT NOT NULL,
    anio_mes NVARCHAR(100) NULL,
    base_mon NVARCHAR(100) NULL,
    m1 NVARCHAR(100) NULL,
    dep_spnf NVARCHAR(100) NULL,
    m1a NVARCHAR(100) NULL,
    otras_oblig NVARCHAR(100) NULL,
    valores_bcn NVARCHAR(100) NULL,
    m2 NVARCHAR(100) NULL,
    otras_spnf NVARCHAR(100) NULL,
    m2a NVARCHAR(100) NULL,
    dep_nores NVARCHAR(100) NULL,
    m3 NVARCHAR(100) NULL,
    m3a NVARCHAR(100) NULL
);

DROP PROCEDURE IF EXISTS 

/* Se indentificó que el valor faltante de OCT 2025 en la tabla de CPI_USA causa conflicto en la aplicación de LAG(12),
Se procede a alterar la view de inflación en donde se transforma para corregir valores posteriores */

CREATE OR ALTER VIEW vw_inflacion_usa AS
 -- Paso 1:
 -- Identificamos el rango de fechas disponible en la tabla CPI_USA.
WITH min_max AS (
SELECT MIN(fecha) AS min_f, MAX(fecha) AS max_f
FROM CPI_USA
),
calendario AS (
-- se procede a crear una serie mensual completa aún con posibles huecos
SELECT 
    min_f AS fecha FROM min_max
	UNION ALL
SELECT 
    DATEADD(MONTH, 1, fecha)
FROM calendario 
WHERE fecha < (SELECT max_f FROM min_max)
), 
datos_completos AS (
-- amarramos la nueva serie mensual con los datos de CPI de la tabla física
SELECT
   c.fecha,
   t.cpi_usa
FROM calendario c
LEFT JOIN CPI_USA t ON  c.fecha = t.fecha
),
calculo AS (
-- calculamos el valor del cpi del año anterior para cada mes
-- notese la diferencia metodológica, en la creación de la view se calculaba la inflación directamente --
SELECT
    fecha,
	cpi_usa,
	LAG(cpi_usa, 12) OVER (ORDER BY fecha) AS cpi_usa_anio_anterior
FROM datos_completos
)
SELECT 
-- se procede a calcular el valor de la inflación int. Aquí el LAG ignora el hueco de oct 2025
    fecha,
	cpi_usa,
	(cpi_usa - cpi_usa_anio_anterior) / cpi_usa_anio_anterior * 100 AS inflacion_interanual_usa2
FROM calculo
WHERE cpi_usa IS NOT NULL
  AND cpi_usa_anio_anterior IS NOT NULL
  -- eliminamos el limite de iteraciones del CTE --
OPTION (MAXRECURSION 0);

/* no se pudo utilizar este método, se aplica alternativa para modificar la view*/ 
CREATE OR ALTER VIEW dbo.vw_inflacion_usa AS
WITH calculo AS (
    SELECT
        actual.fecha,

        -- CPI del mes actual
        actual.cpi_usa,

        -- CPI del mismo mes del año anterior
        previo.cpi_usa AS cpi_usa_anio_anterior

    FROM dbo.CPI_USA AS actual

    -- Self-join para evitar errores si falta algún mes en la serie
    LEFT JOIN dbo.CPI_USA AS previo
        ON previo.fecha = DATEADD(YEAR, -1, actual.fecha)

    -- Solo usamos meses con CPI observado
    WHERE actual.cpi_usa IS NOT NULL
)

SELECT
    fecha,
    cpi_usa,
    cpi_usa_anio_anterior,

    -- Inflación interanual: variación vs mismo mes del año anterior
    (
        (cpi_usa - cpi_usa_anio_anterior)
        / NULLIF(cpi_usa_anio_anterior, 0)
    ) * 100 AS inflacion_interanual_usa

FROM calculo

-- Excluye meses sin dato comparable del año anterior
WHERE cpi_usa_anio_anterior IS NOT NULL;

SELECT *
FROM vw_inflacion_usa
ORDER BY fecha desc;


WITH calculo_inflacion_relativa AS (
SELECT
   i.fecha,
   i.inflacion_interanual AS inflacion_NIC,
   b.deslizamiento_anual,
   b.brecha_deslizamiento,
   iu.inflacion_interanual_usa AS inflacion_USA,
   i.inflacion_interanual - (b.deslizamiento_anual + iu.inflacion_interanual_usa) AS Brecha_Inflacion_Relativa
FROM IPC i
INNER JOIN vw_brecha_deslizamiento b
ON i.fecha = b.fecha
INNER JOIN vw_inflacion_usa iu
ON i.fecha = iu.fecha
ORDER BY i.fecha DESC;


SELECT *
FROM TC


-- Se procede a agregar columna deslizamiento a tabla TC, y se insertan los valores de 2011 de manera manual--
ALTER TABLE dbo.TC
WITH CTE_Deslizamiento AS (
    SELECT 
        deslizamiento_cambiario_anual,
        ((tc - LAG(tc, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(tc, 12) OVER (ORDER BY fecha), 0)) * 100 AS nuevo_valor
    FROM dbo.TC
)
UPDATE CTE_Deslizamiento
SET deslizamiento_cambiario_anual = nuevo_valor;


SELECT
fecha, 
tc,
((tc - LAG(tc, 12) OVER (ORDER BY fecha)) / NULLIF(LAG(tc, 12) OVER (ORDER BY fecha), 0)) * 100  AS deslizamiento
FROM tc

SELECT * 
FROM tc

-- insertamos valores de deslizamiento para 2011 calculados en power query de excel --
WITH src AS (
    SELECT *
    FROM (VALUES
	    ('2011-01-01', 4.99995598),
        ('2011-02-01', 5.00006643),
        ('2011-03-01', 4.73644926),
        ('2011-04-01', 4.72897621),
        ('2011-05-01', 4.73804514),
        ('2011-06-01', 4.73063809),
        ('2011-07-01', 4.73964906),
        ('2011-08-01', 4.74051611),
        ('2011-09-01', 4.73314986),
        ('2011-10-01', 4.74212998),
        ('2011-11-01', 4.73480816),
        ('2011-12-01', 4.74367002)
	) AS v(fecha, deslizamiento_cambiario_anual)
)
UPDATE t
SET t.deslizamiento_cambiario_anual = src.deslizamiento_cambiario_anual
FROM dbo.tc AS t
INNER JOIN src
    ON t.fecha = CONVERT(date, src.fecha);


SELECT * 
FROM vw_crowding_out_spnf
ORDER BY fecha DESC;

-- Diagnóstico: ¿qué columnas tienen NULL en los meses nuevos?
SELECT 
    fecha,
    Base_Monetaria,
    M3,
    M3A,
    M3A - M3 AS diferencia_spnf
FROM BM
WHERE fecha >= '2025-07-01'
ORDER BY fecha;

SELECT * 
FROM vw_crowding_out_spnf
ORDER BY fecha DESC;



WITH base_calculada AS (
    SELECT
        b.fecha,
        c.Credito,
        -- M2A - M2 aísla SPNF sin contaminar con depósitos de no residentes
        -- Metodología BCN 4-15: el salto de M2 a M2A es exclusivamente SPNF
        (b.M2A - b.M2)                                    AS liquidez_spnf,
        -- Peso del SPNF en la liquidez ampliada total
        -- Sin CAST limitado — preservamos precisión nativa para uso en DAX
        (b.M2A - b.M2) * 1.0 / NULLIF(b.M3A, 0)          AS peso_estado
    FROM BM b
    INNER JOIN credito c ON b.fecha = c.fecha
    WHERE b.M2A IS NOT NULL
      AND b.M2  IS NOT NULL
),
con_rezagos AS (
    SELECT
        fecha,
        peso_estado,
        liquidez_spnf,
        Credito,
        LAG(liquidez_spnf, 12) OVER (ORDER BY fecha) AS liquidez_spnf_ant,
        LAG(Credito,       12) OVER (ORDER BY fecha) AS credito_ant
    FROM base_calculada
)
SELECT
    fecha,
    peso_estado,
    -- Variación interanual del volumen absoluto de liquidez SPNF
    -- Positivo = el Estado está expandiendo su liquidez más rápido que el año anterior
    (liquidez_spnf - liquidez_spnf_ant) 
        / NULLIF(liquidez_spnf_ant, 0) * 100             AS var_inter_spnf,
    -- Variación interanual del crédito al sector privado
    -- El diferencial entre ambas variaciones define el crowding out
    (Credito - credito_ant) 
        / NULLIF(credito_ant, 0) * 100                   AS var_inter_credito
FROM con_rezagos
WHERE liquidez_spnf_ant IS NOT NULL
  AND credito_ant        IS NOT NULL
  ORDER BY fecha desc;

  SELECT 
    fecha,
    M2,
    M2A,
    M3,
    M3A,
    (M2A - M2) AS spnf_m2,
    (M3A - M3) AS spnf_m3
FROM BM
WHERE fecha >= '2025-07-01'
ORDER BY fecha;


SELECT *
FROM BM 
ORDER BY fecha DESC;

-- Procedo a actualizar M2A de BM de Jul - Dec 2025 por un error en el csv de stagging -- 
WITH src AS (
SELECT *
FROM (VALUES
     ('2025-07-01', 278536.5000),
	 ('2025-08-01', 275853.3000),
	 ('2025-09-01', 277304.3000),
	 ('2025-10-01', 289820.8000),
	 ('2025-11-01', 295143.2000),
	 ('2025-12-01', 302839.8000)
	 ) AS v(fecha, M2A_nuevo)
)
UPDATE b 
SET b.M2A = src.M2A_nuevo
FROM BM b
INNER JOIN src
ON b.fecha = CONVERT(DATE, src.fecha);
