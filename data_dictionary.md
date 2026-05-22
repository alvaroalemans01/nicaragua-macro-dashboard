# Diccionario de Datos

Referencia de todas las tablas fuente, vistas analíticas y carpetas de medidas del modelo.

---

## Tablas Fuente (SQL Server)

Todas las tablas fueron cargadas mediante **Power Query (M)** desde archivos CSV del BCN, SECMCA y FRED. Power Query se usó para limpieza de tipos, normalización de fechas, y eliminación de filas vacías antes de la carga a SQL Server.

| Tabla | Fuente | Contenido |
|---|---|---|
| `IMAE` | BCN | Índice Mensual de Actividad Económica — actividad real desestacionalizada y tendencia-ciclo |
| `IPC` | BCN | Índice de Precios al Consumidor — mensual, base nacional |
| `TC` | BCN | Tipo de cambio oficial córdoba/dólar (referencia diaria/mensual) |
| `BM` | BCN | Base Monetaria (pasivos del BCN: circulante + reservas bancarias) |
| `RIN` | BCN | Reservas Internacionales Netas en millones de USD |
| `credito` | BCN | Cartera de crédito del sistema financiero por sector y moneda |
| `TRM` | BCN | Tipo de Cambio Real Multilateral (índice) |
| `tasa_interbancaria` | BCN | Tasa interbancaria overnight en córdobas |
| `Tasas_Interes_BCN` | BCN | Tasas activas y pasivas del sistema financiero por plazo y moneda |
| `CPI_USA` | FRED (BLS) | Consumer Price Index - All Urban Consumers (CPIAUCSL), mensual |
| `Dim_monedas` | Manual | Tabla de dimensión: MN (córdobas) / ME (dólares) |
| `Calendario` | Power Query | Tabla de fechas continua 2011–2026, generada en Power Query |

---

## Vistas Analíticas (SQL Server)

Las vistas consolidan y transforman las tablas fuente para consumo directo desde Power BI, evitando transformaciones pesadas en DAX.

| Vista | Propósito |
|---|---|
| `vw_macroeconomico` | Indicadores macro principales: IMAE, IPC, TC, BM, RIN consolidados por fecha |
| `vw_brecha_deslizamiento` | Cálculo de la brecha entre inflación y deslizamiento cambiario |
| `vw_tipo_cambio_real` | TCR efectivo y desviaciones respecto al promedio histórico |
| `vw_inflacion_usa` | Serie CPI USA con manejo del hueco Oct–Nov 2025 (CTE recursivo + LAG 12) |
| `vw_spread_bancario` | Spread activo–pasivo por plazo (CP y LP) y moneda (MN y ME) |
| `vw_Tasa_Real_Colocacion` | Tasa activa deflactada por inflación — costo real del crédito |
| `vw_dinamismo_real_financiero` | Variaciones interanuales del crédito real desagregado |
| `vw_crowding_out_spnf` | Peso del sector público en el crédito total del sistema |
| `vw_EstructuraPlazos_Spread` | Curva de tasas por plazo — spread CP vs LP |
| `vw_cobertura_res_agregados_monetarios` | Cobertura de las RIN sobre M1, M2, M2A (vulnerabilidad externa) |
| `vw_exposicion_externa` | Exposición del sistema financiero a pasivos en ME y no residentes |
| `vw_paridad_real_de_tasas` | Diferencial de tasas reales MN vs ME ajustado por inflación y TC esperado |

---

## Medidas DAX (_Medidas)

La tabla `_Medidas` (prefijo guión bajo — requerido por el MCP de Power BI Modeling) contiene **99 medidas** (en proceso de limpieza) organizadas en 5 carpetas de visualización:

### H1_VisionMacro (22 medidas)
KPIs y series para la página de visión general. Incluye el estado macro semáforo (`Estado_Macro_Actual`), zonas de expansión/contracción del IMAE, y variaciones interanuales de BM y M2.

### H2_Inflacion (18 medidas)
Análisis de anclaje cambiario. Incluye `Brecha_PPA_Serie` (NIC − desl − USA), zonas de presión/deflación, comparativa inflación NIC vs USA con bandas meta BCN (2%–3%), y `Indicador_Status_TCR`.

### H3_SistemaFinanciero (15 medidas)
Spreads bancarios CP/LP, correlación IMAE–crédito (0.45 interanual), crowding-out SPNF con `Crowding_Buffer`, y LDR centrado en umbral 75% con zonas v2.

### H4_TasasCredito (7 medidas)
Tasas reales de colocación CP y LP, spread por plazos, paridad real de tasas MN vs ME. *Página en construcción.*

### H5_RiesgoEstabilidad (5 medidas)
Cobertura RIN/M1, RIN/M2, RIN/M2A, exposición externa como % del sistema, y variación interanual de RIN. *Página en construcción.*

---

## Notas de Escala

| Tabla | Columna(s) afectada(s) | Escala actual | Estado |
|---|---|---|---|
| `Tasas_Interes_BCN` | tasas activas y pasivas | Entero (4.06 = 4.06%) | Pendiente corrección en SSMS |
| `IPC` | variación | Entero | Pendiente |
| Otras | varias | Entero | DAX aplica `/100` como workaround |

> Pendiente: normalizar todas las columnas de tasa a decimal (`0.0406`) directamente en SQL Server para eliminar la dependencia de `/100` en DAX.

---

*Última actualización: mayo 2026*
