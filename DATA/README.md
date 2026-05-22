# SQL Scripts

Execute scripts in numbered order against your SQL Server instance.

| Script | Description |
|---|---|
| `01_create_tables.sql` | DDL for all base tables: IMAE, IPC, TC, BM (+ M1/M1A/M2/M2A/M3/M3A columns), RIN (+ RIN_NIO column), credito, TRM, tasa_interbancaria, Tasas_Interes_BCN, CPI_USA, Dim_monedas |
| `02_create_staging.sql` | Creates `staging_agg_monetarios` and `staging_agg_monetarios_backup` tables used by the ETL stored procedure |
| `03_sp_actualizar_BM.sql` | **Main ETL stored procedure** — see detail below |
| `04_create_views.sql` | All 12 analytical views in dependency order |
| `05_backfill_deslizamiento.sql` | Manual backfill of `deslizamiento_cambiario_anual` for 2011 (values pre-date the LAG window) |
| `06_validation_queries.sql` | Row counts, date ranges, null checks, and dependency inventory |

---

## ETL Stored Procedure: `sp_actualizar_BM_desde_csv`

The most complex piece of the pipeline. Handles the BCN's monetary aggregates report (Cuadro 4-14/4-15), which ships as a pivot CSV with years and Spanish month names interleaved as rows — not a clean tabular format.

**6-station CTE pipeline inside a single atomic transaction:**

```
Station 1 — Categorización
  Detects whether each raw row is a year header or a month row
  using ISNUMERIC(LEFT(value, 4))

Station 2 — Agrupación
  Creates running year groups using COUNT(anio_detectado) OVER(ORDER BY RowID)

Station 3 — Fill-Down
  Propagates the year value down to month rows within each group
  using MAX(anio_detectado) OVER(PARTITION BY grupo_anio)

Station 4 — Limpieza y Fechas
  Maps Spanish month names → month numbers (CASE WHEN LIKE 'Enero%'...)
  Filters out 'Promedio' summary rows

Station 5 — Columnas Limpias
  Numeric cleaning: TRIM → REPLACE(',','') → TRY_CAST to DECIMAL(18,4)
  Handles BCN convention of parenthetical negatives: (1,234.5) → -1234.5
  Builds DATE with DATEFROMPARTS(year, month, 1)

Station 6 — Deduplicación
  GROUP BY fecha + MAX() to collapse any duplicate staging rows

→ MERGE (UPSERT) into dbo.BM
  WHEN MATCHED → UPDATE
  WHEN NOT MATCHED → INSERT
  Wrapped in BEGIN TRAN / TRY-CATCH / ROLLBACK
```

**To run:** `EXEC dbo.sp_actualizar_BM_desde_csv @RutaArchivo = N'C:\path\to\file.csv'`

---

## Notes

- Initial data cleaning (type normalization, date parsing, null removal for simpler tables) was performed in **Power Query (M)** before loading to SQL Server. The stored procedure handles the complex BCN pivot format that Power Query cannot cleanly parse.
- `vw_inflacion_usa` uses a **self-join** (`LEFT JOIN CPI_USA AS previo ON previo.fecha = DATEADD(YEAR, -1, actual.fecha)`) to handle the missing Oct–Nov 2025 CPI data. Do not replace with LAG(12) — LAG breaks when there are gaps in the series.
- `vw_tipo_cambio_real` uses **CROSS JOIN** to project scalar base-year constants (IPC Jan 2011, CPI Jan 2011) across the full time series — avoids correlated subqueries in the SELECT clause.
- Percentage columns in `Tasas_Interes_BCN` store rates as integers (e.g., `4.06` for 4.06%). DAX measures apply `/100` where needed. Normalization in SQL is pending.
