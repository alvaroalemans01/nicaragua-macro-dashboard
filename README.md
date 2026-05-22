# 🟦⬜Nicaragua Macroeconomic Intelligence Dashboard

> **Personal portfolio project** — end-to-end macroeconomic analytics pipeline for Nicaragua, built on SQL Server, Power BI, and DAX. Covers monetary aggregates, inflation dynamics, exchange rate policy, banking system health, and external vulnerability across 7 analytical pages (2011–2025).

---

## 📌Stack

| Layer | Tool |
|---|---|
| Data ingestion & cleaning | Power Query (M) |
| Storage & transformation | SQL Server (SSMS) + T-SQL views |
| Visualization & measures | Power BI Desktop + DAX |
| Version control / docs | GitHub |

---

## 🔢Data Sources

| Source | Coverage |
|---|---|
| [Banco Central de Nicaragua (BCN)](https://www.bcn.gob.ni) | IMAE, IPC, TC, RIN, BM, crédito, tasas de interés, agregados monetarios |
| [SECMCA](https://www.secmca.org) | Tasas regionales de referencia |
| [FRED – Federal Reserve Bank of St. Louis](https://fred.stlouisfed.org) | CPI USA (serie mensual) |

> Raw CSVs are not included in this repo (third-party data). See [`data/README.md`](data/README.md) for download instructions.

---

## 🌳Dashboard Structure

| Page | Question answered | Status |
|---|---|---|
| **H1 — Visión Macro** | ¿Cómo está la economía? | ✅ ~90% |
| **H2 — Inflación y Anclaje** | ¿Está funcionando la política cambiaria? | ✅ ~90% |
| **H3 — Sistema Financiero** | ¿Cómo responde el sistema al entorno? | ✅ ~90% |
| **H4 — Tasas y Crédito** | ¿A qué costo llega el crédito a la economía? | 🔄 In progress |
| **H5 — Riesgo y Estabilidad** | ¿Qué tan expuesta está la economía a shocks externos? | 🔄 In progress |
| Pages 6–7 | TBD | ⏳ Pending |

---

## 🔍 Key Analytical Findings

- **Post-crisis recovery confirmed**: IMAE growth has remained above the BCN 3.5% expansion threshold through 2023–2025, consolidating the recovery from the 2018 sociopolitical crisis and the 2020 COVID shock.

- **PPA gap as a net domestic pressure gauge**: With the crawling peg fixed at 0% since 2023, the Purchasing Power Parity gap (NIC inflation − devaluation − US inflation) now functions as a direct, uncontaminated measure of domestic price pressure — a structural change in how monetary anchoring should be interpreted.

- **Banking sector in efficient intermediation zone**: The Loan-to-Deposit Ratio (LDR) stands at ~78%, placing the system in the 75–85% efficient intermediation range. M3A is used as the deposit proxy to capture total systemic liquidity. See [methodology note](docs/methodology.md#ldr).

- **State-Backed Liquidity Cushion (2018–2020 Recovery):** Counter-intuitive pipeline analysis proves that following the 2018 banking panic, the spike in public sector liquidity (`M2A - M2` peaking at ~20%) did **not** crowd out private credit. Instead, commercial banks utilized these stable state deposits as an emergency pool of loanable funds to sustain and revive private productive credit until agent confidence normalized by 2025 (~14%).

- **Córdoba term premium is structural**: The long-term bank spread in MN (~11%) is approximately 3× the ME equivalent (~3.5%), revealing that banks price long-term córdoba credit with a structural risk premium that does not exist for USD-denominated loans.

- **TCR assessment without fixed thresholds**: The Real Exchange Rate is evaluated against its own historical average rather than a fixed benchmark, avoiding the false precision of PPP-based equilibrium estimates for a small, dollarized economy.

---

## Model Architecture

```
SQL Server (SSMS)
├── Base tables: IMAE, IPC, TC, BM, RIN, credito, TRM,
│               tasa_interbancaria, Tasas_Interes_BCN,
│               CPI_USA, Dim_monedas, Calendario
└── Analytical views (12):
    vw_macroeconomico, vw_brecha_deslizamiento,
    vw_tipo_cambio_real, vw_inflacion_usa,
    vw_spread_bancario, vw_Tasa_Real_Colocacion,
    vw_dinamismo_real_financiero, vw_crowding_out_spnf,
    vw_EstructuraPlazos_Spread,
    vw_cobertura_res_agregados_monetarios,
    vw_exposicion_externa, vw_paridad_real_de_tasas

Power BI Desktop (proyectomacro.pbix)
├── _Medidas table (99 DAX measures, 5 display folders)
├── KPI scalar pattern (dual-use: card + time series)
└── Conditional formatting via Estado_*_Valor measures
```

---

## Notable Technical Decisions

See [`docs/methodology.md`](docs/methodology.md) and [`docs/dax_patterns.md`](docs/dax_patterns.md) for full documentation. Highlights:

- **M3 vs M3A**: M3 aggregates include **non-resident** deposits (unlike M2). Intentional per BCN methodology -- documented explicitly to prevent misinterpretation.
- **CPI USA data gap**: Oct-Nov 2025 values officially missing (U.S. government lapse in appropriations). Handled via self-join on CPI_USA -- not imputed, not LAG(12) which breaks on gaps.
- **ETL for monetary aggregates**: BCN pivot CSV has years and Spanish month names interleaved as rows. A 6-station CTE stored procedure parses, cleans, and UPSERTs via atomic MERGE. See [`sql/README.md`](sql/README.md)..

---

## Screenshots
<img width="1365" height="544" alt="image" src="https://github.com/user-attachments/assets/96778a38-510f-4aad-9c09-8ed6bdccf2c1" />
<img width="1365" height="715" alt="image" src="https://github.com/user-attachments/assets/b40cf0ce-5812-4824-9f57-762a94511bc9" />
<img width="1365" height="719" alt="image" src="https://github.com/user-attachments/assets/bec67e3d-8f94-4b02-abdd-aba88670841b" />


*Coming soon — dashboard export pending completion of H4 and H5.*

---

## How to Reproduce

1. Download source CSVs from BCN, SECMCA, and FRED (see [`data/README.md`](data/README.md))
2. Run SQL scripts in `/sql` in numbered order to create tables and views
3. Open `proyectomacro.pbix` in Power BI Desktop
4. Update the SQL Server connection string to point to your local instance

---

*Built by Álvaro Alemán — Economist & Data Analyst | [LinkedIn](#)*
