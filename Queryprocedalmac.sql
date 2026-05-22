SELECT TOP 20 *
FROM credito
ORDER BY fecha DESC;

SELECT *
FROM credito 
ORDER BY fecha DESC;


SELECT *
FROM vw_cobertura_res_agregados_monetarios

SELECT *
FROM vw_macroeconomico


SELECT * 
FROM tasa_interbancaria

SELECT 
    c.name AS columna,
    t.name AS tipo_dato,
    c.is_identity
FROM sys.columns c
JOIN sys.types t 
    ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.staging_agg_monetarios');

--Habilitamos openrowset --
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;

EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;


--Creamos el stored procedure -- 
CREATE OR ALTER PROCEDURE dbo.sp_actualizar_BM_desde_csv
    @RutaArchivo NVARCHAR(4000) = N'C:\Users\alvar\OneDrive\Documentos\Recursos Proyecto Macro\stagingaggmonetariosBCN.csv'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        --------------------------------------------------------------------
        -- 1. Limpiar staging físico
        --    La staging solo debe contener la carga actual del archivo raw.
        --------------------------------------------------------------------
        TRUNCATE TABLE dbo.staging_agg_monetarios;

        --------------------------------------------------------------------
        -- 2. Cargar CSV a staging
        --    No insertamos RowID; SQL Server lo genera si es IDENTITY.
        --------------------------------------------------------------------
        DECLARE @sql NVARCHAR(MAX);

        SET @sql = N'
            INSERT INTO dbo.staging_agg_monetarios
            (
                anio_mes,
                base_mon,
                m1,
                dep_spnf,
                m1a,
                otras_oblig,
                valores_bcn,
                m2,
                otras_spnf,
                m2a,
                dep_nores,
                m3,
                m3a
            )
            SELECT
                anio_mes,
                base_mon,
                m1,
                dep_spnf,
                m1a,
                otras_oblig,
                valores_bcn,
                m2,
                otras_spnf,
                m2a,
                dep_nores,
                m3,
                m3a
            FROM OPENROWSET(
                BULK ''' + REPLACE(@RutaArchivo, '''', '''''') + N''',
                FORMAT = ''CSV'',
                FIRSTROW = 2,
                FIELDQUOTE = ''"'',
                CODEPAGE = ''65001''
            )
            WITH (
                anio_mes      NVARCHAR(100) 1,
                base_mon      NVARCHAR(100) 2,
                m1            NVARCHAR(100) 3,
                dep_spnf      NVARCHAR(100) 4,
                m1a           NVARCHAR(100) 5,
                otras_oblig   NVARCHAR(100) 6,
                valores_bcn   NVARCHAR(100) 7,
                m2            NVARCHAR(100) 8,
                otras_spnf    NVARCHAR(100) 9,
                m2a           NVARCHAR(100) 10,
                dep_nores     NVARCHAR(100) 11,
                m3            NVARCHAR(100) 12,
                m3a           NVARCHAR(100) 13
            ) AS src;
        ';

        EXEC sys.sp_executesql @sql;

        --------------------------------------------------------------------
        -- 3. Limpiar, transformar y actualizar BM
        --------------------------------------------------------------------
        ;WITH estacion_1_categorizacion AS (
            SELECT
                RowID,

                -- Detectar filas que contienen año.
                CASE 
                    WHEN LEN(TRIM(anio_mes)) >= 4 
                         AND ISNUMERIC(LEFT(TRIM(anio_mes), 4)) = 1
                    THEN LEFT(TRIM(anio_mes), 4)
                    ELSE NULL
                END AS anio_detectado,

                -- Detectar filas que contienen mes.
                CASE 
                    WHEN LEN(TRIM(anio_mes)) >= 4 
                         AND ISNUMERIC(LEFT(TRIM(anio_mes), 4)) = 0 
                    THEN TRIM(anio_mes)
                    ELSE NULL
                END AS mes_detectado,

                base_mon,
                m1,
                dep_spnf,
                m1a,
                otras_oblig,
                valores_bcn,
                m2,
                otras_spnf,
                m2a,
                dep_nores,
                m3,
                m3a
            FROM dbo.staging_agg_monetarios
            WHERE anio_mes IS NOT NULL
        ),

        estacion_2_agrupacion AS (
            SELECT 
                *,
                COUNT(anio_detectado) OVER(ORDER BY RowID) AS grupo_anio
            FROM estacion_1_categorizacion
        ),

        estacion_3_filldown AS (
            SELECT 
                *,
                MAX(anio_detectado) OVER(PARTITION BY grupo_anio) AS anio_real
            FROM estacion_2_agrupacion
        ),

        estacion_4_limpieza_y_fechas AS ( 
            SELECT 
                *,
                CASE 
                    WHEN mes_detectado LIKE 'Enero%'      THEN 1 
                    WHEN mes_detectado LIKE 'Febrero%'    THEN 2 
                    WHEN mes_detectado LIKE 'Marzo%'      THEN 3
                    WHEN mes_detectado LIKE 'Abril%'      THEN 4 
                    WHEN mes_detectado LIKE 'Mayo%'       THEN 5 
                    WHEN mes_detectado LIKE 'Junio%'      THEN 6
                    WHEN mes_detectado LIKE 'Julio%'      THEN 7 
                    WHEN mes_detectado LIKE 'Agosto%'     THEN 8 
                    WHEN mes_detectado LIKE 'Septiembre%' THEN 9
                    WHEN mes_detectado LIKE 'Octubre%'    THEN 10 
                    WHEN mes_detectado LIKE 'Noviembre%'  THEN 11 
                    WHEN mes_detectado LIKE 'Diciembre%'  THEN 12
                END AS numero_mes
            FROM estacion_3_filldown
            WHERE mes_detectado IS NOT NULL 
              AND mes_detectado NOT LIKE '%Promedio%'
        ),

        estacion_5_columnas_limpias AS (
            SELECT 
                DATEFROMPARTS(CAST(anio_real AS INT), numero_mes, 1) AS fecha,

                CASE 
                    WHEN TRIM(base_mon) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(base_mon), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(base_mon), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS base_monetaria,

                CASE 
                    WHEN TRIM(m1) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m1), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m1), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M1,

                CASE 
                    WHEN TRIM(m1a) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m1a), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m1a), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M1A,

                CASE 
                    WHEN TRIM(m2) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m2), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m2), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M2,

                CASE 
                    WHEN TRIM(m2a) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m2a), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m2a), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M2A,

                CASE 
                    WHEN TRIM(m3) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m3), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m3), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M3,

                CASE 
                    WHEN TRIM(m3a) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m3a), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m3a), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M3A

            FROM estacion_4_limpieza_y_fechas
            WHERE numero_mes IS NOT NULL
        ),

        estacion_6_final AS (
            -- Defensa adicional por si el archivo trae alguna fecha duplicada.
            -- Para una serie mensual debería haber una única fila por fecha.
            SELECT
                fecha,
                MAX(base_monetaria) AS base_monetaria,
                MAX(M1) AS M1,
                MAX(M1A) AS M1A,
                MAX(M2) AS M2,
                MAX(M2A) AS M2A,
                MAX(M3) AS M3,
                MAX(M3A) AS M3A
            FROM estacion_5_columnas_limpias
            GROUP BY fecha
        )

        MERGE dbo.BM AS target
        USING estacion_6_final AS source
            ON target.fecha = source.fecha

        WHEN MATCHED THEN
            UPDATE SET
                target.Base_Monetaria = source.base_monetaria,
                target.M1 = source.M1,
                target.M1A = source.M1A,
                target.M2 = source.M2,
                target.M2A = source.M2A,
                target.M3 = source.M3,
                target.M3A = source.M3A

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                fecha,
                Base_Monetaria,
                M1,
                M1A,
                M2,
                M2A,
                M3,
                M3A
            )
            VALUES (
                source.fecha,
                source.base_monetaria,
                source.M1,
                source.M1A,
                source.M2,
                source.M2A,
                source.M3,
                source.M3A
            );

        COMMIT TRAN;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;
    END CATCH
END;
-- se valida --
EXEC dbo.sp_actualizar_BM_desde_csv
    @RutaArchivo = N'C:\Users\alvar\OneDrive\Documentos\Recursos Proyecto Macro\stagingaggmonetariosBCN.csv';


TRUNCATE TABLE dbo.staging_agg_monetarios;

BULK INSERT dbo.staging_agg_monetarios
FROM 'C:\Users\alvar\OneDrive\Documentos\Recursos Proyecto Macro\stagingaggmonetariosBCN.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    TABLOCK
);


DROP TABLE dbo.staging_agg_monetarios;

--modificamos stored procedure para actualizar tabla de agregados monetarios -- 

CREATE OR ALTER PROCEDURE dbo.sp_actualizar_BM_desde_staging
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        ;WITH estacion_1_categorizacion AS (
            SELECT
                RowID,

                -- Detecta filas que contienen años.
                -- Ejemplo: '2011', '2012', '2026'
                CASE 
                    WHEN LEN(TRIM(anio_mes)) >= 4 
                         AND ISNUMERIC(LEFT(TRIM(anio_mes), 4)) = 1
                    THEN LEFT(TRIM(anio_mes), 4)
                    ELSE NULL
                END AS anio_detectado,

                -- Detecta filas que contienen meses.
                -- Ejemplo: 'Enero', 'Febrero', 'Diciembre'
                CASE 
                    WHEN LEN(TRIM(anio_mes)) >= 4 
                         AND ISNUMERIC(LEFT(TRIM(anio_mes), 4)) = 0 
                    THEN TRIM(anio_mes)
                    ELSE NULL
                END AS mes_detectado,

                base_mon,
                m1,
                dep_spnf,
                m1a,
                otras_oblig,
                valores_bcn,
                m2,
                otras_spnf,
                m2a,
                dep_nores,
                m3,
                m3a
            FROM dbo.staging_agg_monetarios_backup   -- CAMBIA AQUÍ si tu tabla tiene otro nombre
            WHERE anio_mes IS NOT NULL
        ),

        estacion_2_agrupacion AS (
            SELECT 
                *,
                -- Crea un grupo acumulado cada vez que aparece un nuevo año.
                -- Esto permite asociar los meses siguientes con su año correspondiente.
                COUNT(anio_detectado) OVER(ORDER BY RowID) AS grupo_anio
            FROM estacion_1_categorizacion
        ),

        estacion_3_filldown AS (
            SELECT 
                *,
                -- Rellena el año hacia abajo dentro de cada grupo.
                -- Ejemplo:
                -- 2026
                -- Enero   -> 2026
                -- Febrero -> 2026
                MAX(anio_detectado) OVER(PARTITION BY grupo_anio) AS anio_real
            FROM estacion_2_agrupacion
        ),

        estacion_4_limpieza_y_fechas AS ( 
            SELECT 
                *,
                -- Convierte el nombre del mes a número de mes.
                CASE 
                    WHEN mes_detectado LIKE 'Enero%'      THEN 1 
                    WHEN mes_detectado LIKE 'Febrero%'    THEN 2 
                    WHEN mes_detectado LIKE 'Marzo%'      THEN 3
                    WHEN mes_detectado LIKE 'Abril%'      THEN 4 
                    WHEN mes_detectado LIKE 'Mayo%'       THEN 5 
                    WHEN mes_detectado LIKE 'Junio%'      THEN 6
                    WHEN mes_detectado LIKE 'Julio%'      THEN 7 
                    WHEN mes_detectado LIKE 'Agosto%'     THEN 8 
                    WHEN mes_detectado LIKE 'Septiembre%' THEN 9
                    WHEN mes_detectado LIKE 'Octubre%'    THEN 10 
                    WHEN mes_detectado LIKE 'Noviembre%'  THEN 11 
                    WHEN mes_detectado LIKE 'Diciembre%'  THEN 12
                END AS numero_mes
            FROM estacion_3_filldown
            WHERE mes_detectado IS NOT NULL 
              AND mes_detectado NOT LIKE '%Promedio%'
        ),

        estacion_5_columnas_limpias AS (
            SELECT 
                -- Construye fecha mensual estándar.
                DATEFROMPARTS(CAST(anio_real AS INT), numero_mes, 1) AS fecha,

                -- Limpieza numérica:
                -- 1. TRIM elimina espacios.
                -- 2. REPLACE elimina separador de miles.
                -- 3. TRY_CAST convierte texto a número.
                -- 4. Si el valor viene entre paréntesis, se interpreta como negativo.

                CASE 
                    WHEN TRIM(base_mon) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(base_mon), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(base_mon), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS base_monetaria,

                CASE 
                    WHEN TRIM(m1) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m1), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m1), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M1,

                CASE 
                    WHEN TRIM(m1a) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m1a), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m1a), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M1A,

                CASE 
                    WHEN TRIM(m2) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m2), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m2), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M2,

                CASE 
                    WHEN TRIM(m2a) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m2a), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m2a), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M2A,

                CASE 
                    WHEN TRIM(m3) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m3), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m3), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M3,

                CASE 
                    WHEN TRIM(m3a) LIKE '(%)'
                    THEN -1 * TRY_CAST(REPLACE(REPLACE(REPLACE(TRIM(m3a), ',', ''), '(', ''), ')', '') AS DECIMAL(18,4))
                    ELSE TRY_CAST(REPLACE(REPLACE(TRIM(m3a), ',', ''), ' ', '') AS DECIMAL(18,4))
                END AS M3A

            FROM estacion_4_limpieza_y_fechas
            WHERE numero_mes IS NOT NULL
        ),

        estacion_6_final AS (
            -- Defensa por si staging trae fechas duplicadas.
            -- Para una serie mensual debe quedar una sola fila por fecha.
            SELECT
                fecha,
                MAX(base_monetaria) AS base_monetaria,
                MAX(M1) AS M1,
                MAX(M1A) AS M1A,
                MAX(M2) AS M2,
                MAX(M2A) AS M2A,
                MAX(M3) AS M3,
                MAX(M3A) AS M3A
            FROM estacion_5_columnas_limpias
            GROUP BY fecha
        )

        MERGE dbo.BM AS target
        USING estacion_6_final AS source
            ON target.fecha = source.fecha

        WHEN MATCHED THEN
            UPDATE SET
                target.Base_Monetaria = source.base_monetaria,
                target.M1 = source.M1,
                target.M1A = source.M1A,
                target.M2 = source.M2,
                target.M2A = source.M2A,
                target.M3 = source.M3,
                target.M3A = source.M3A

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (
                fecha,
                Base_Monetaria,
                M1,
                M1A,
                M2,
                M2A,
                M3,
                M3A
            )
            VALUES (
                source.fecha,
                source.base_monetaria,
                source.M1,
                source.M1A,
                source.M2,
                source.M2A,
                source.M3,
                source.M3A
            );

        COMMIT TRAN;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        THROW;
    END CATCH
END;

EXEC dbo.sp_actualizar_BM_desde_staging;

SELECT *
FROM BM
ORDER BY fecha desc

SELECT * 
FROM vw_cobertura_res_agregados_monetarios
ORDER BY fecha DESC;

SELECT *
FROM CPI_USA
ORDER BY fecha desc

SELECT *
FROM vw_inflacion_usa
ORDER BY fecha DESC;

SELECT *
FROM vw_macroeconomico