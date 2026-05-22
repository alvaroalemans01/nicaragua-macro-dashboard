# Metodología y Decisiones de Modelado

Este documento registra las decisiones técnicas y metodológicas del proyecto, con sus justificaciones. El objetivo es que cualquier persona que revise el repositorio entienda *por qué* el modelo está construido de esta manera, no solo *cómo*.

---

## 1. Agregados Monetarios: M2, M2A, M3 y M3A

### Definición operativa usada

| Agregado | Incluye depósitos de... |
|---|---|
| M2 | Residentes |
| M2A | Residentes + ajuste estacional |
| **M3** | **Residentes + No residentes** |
| M3A | Residentes + No residentes + ajuste |

> ⚠️ **Nota crítica**: M3 suma depósitos de **no residentes**, a diferencia de M2. Esto sigue la metodología oficial del BCN. Cualquier comparación internacional o regional debe tener esto en cuenta, ya que la mayoría de los frameworks estándar (FMI, BCE) excluyen no residentes de M3.

### Por qué M3A como denominador del LDR {#ldr}

El Loan-to-Deposit Ratio (LDR) requiere un proxy del total de depósitos del sistema financiero. Se usa **M3A** porque:
- Captura la liquidez total disponible del sistema, incluyendo el componente externo que efectivamente fondea operaciones domésticas.
- M2 subestimaría el denominador, inflando artificialmente el LDR.
- Limitación: M3A incluye pasivos de no residentes que pueden ser más volátiles. **Se documenta explícitamente como aproximación (proxy), no como medición exacta.**

---

## 2. Brecha PPA (Purchasing Power Parity Gap)

### Fórmula

```
Brecha_PPA = Inflación_NIC - Deslizamiento - Inflación_USA
```

### Evolución del concepto

La versión anterior calculaba `Inflación_NIC - Deslizamiento`, lo que era redundante: con deslizamiento = 0% desde 2023, la brecha era idéntica a la inflación nicaragüense. Se incorporó `Inflación_USA` como componente para medir la **presión doméstica neta** — lo que Nicaragua inflaciona *por encima* de lo que debería esperarse dado el ancla cambiaria y el contexto externo.

### Zonas de interpretación

| Brecha | Lectura |
|---|---|
| > 0 | Presión inflacionaria doméstica — el ancla absorbe tensión |
| ≈ 0 | Equilibrio — la política cambiaria funciona como ancla efectiva |
| < 0 | Presión deflacionaria — potencial sobrevaluación real |

---

## 3. Tipo de Cambio Real (TCR)

### Decisión: sin umbrales fijos

El TCR **no** se evalúa contra un valor de equilibrio fijo (e.g., indexado a 100 en año base). Razones:

1. Para una economía pequeña y parcialmente dolarizada como Nicaragua, los modelos de equilibrio del TCR (BEER, FEER) requieren supuestos de calibración que no están disponibles públicamente.
2. Un umbral fijo implica precisión que el modelo no tiene.

### Enfoque adoptado

Se usa el **promedio histórico de la serie** (`Ref_Promedio_TCR`) como referencia dinámica, complementado con `Indicador_Status_TCR` que detecta desviaciones significativas respecto al promedio. La escala real del TCR en el modelo es ~20–26 (no indexada a 100).

---

## 4. LDR — Loan-to-Deposit Ratio

### Umbral de intermediación eficiente

- **< 75%**: Subutilización — el sistema tiene capacidad ociosa
- **75%–85%**: Zona eficiente — equilibrio entre rentabilidad y liquidez
- **> 85%**: Presión de liquidez — riesgo de estrés sistémico

### Implementación visual: técnica de centrado en umbral

En lugar de mostrar el LDR absoluto con una línea al 75%, se calcula:

```dax
LDR_vs_Umbral = LDR - 0.75
```

Esto centra el visual en 0, haciendo que las zonas de eficiencia/riesgo sean simétricas y visualmente inmediatas. La misma técnica se usa en `Brecha_PPA` y `Crowding_Buffer`.

---

## 5. Crowding-Out SPNF

### Lógica del indicador

`Peso_SPNF = Crédito al Sector Público / Crédito Total`

Mide qué fracción del crédito bancario está absorbida por el Estado, potencialmente desplazando al sector privado.

- **Umbral de alerta**: 20%
- **Máximo histórico observado**: ~19% (2018–2020, período de crisis)
- **Valor actual (2025)**: ~14%

### Implementación visual: Crowding_Buffer

```dax
Crowding_Buffer = 0.20 - Peso_SPNF_Serie
```

Se apila sobre `Peso_SPNF_Serie` en un gráfico de columnas apiladas. El sliver resultante se *comprime visualmente* cuando el SPNF se acerca al umbral — la historia del near-miss se lee sin que el umbral se cruce.

> ⚠️ `Crowding_Zona_Alerta` es una medida obsoleta (activaría solo si SPNF > 20%, lo que nunca ocurrió). Pendiente de eliminar del modelo.

---

## 6. Correlación IMAE–Crédito

### Decisión: variación interanual, no mensual

La correlación mensual entre IMAE y crédito es ~0.16 (ruido estacional domina). La variación **interanual** produce 0.45 — co-movimiento real del ciclo, no estacionalidad. 

**Interpretación correcta**: co-movimiento del ciclo económico, no causalidad. El crédito y la actividad se mueven juntos en el ciclo, pero la dirección causal no está establecida en este modelo.

---

## 7. CPI USA — Dato Faltante (Oct–Nov 2025)

Los datos del CPI de Estados Unidos correspondientes a octubre y noviembre de 2025 **no fueron publicados oficialmente** debido a un *lapse in appropriations* (cierre parcial del gobierno federal de EE.UU.).

### Manejo en el modelo

`vw_inflacion_usa` usa un CTE recursivo con calendario continuo + `LAG(12)` para mantener la continuidad de la serie. Los valores faltantes **no son imputados** — el modelo reconoce el hueco y lo maneja estructuralmente.

> Esta decisión debe revisarse cuando BLS publique los datos retroactivos.

---

## 8. Escala de Porcentajes en Tablas Fuente

Varias columnas almacenan tasas como enteros en lugar de decimales (e.g., `4.06` para 4.06% en lugar de `0.0406`).

- **Estado actual**: Las medidas DAX aplican `/100` donde es necesario.
- **Pendiente**: Normalizar a decimal directamente en las tablas de SQL Server para eliminar la dependencia de transformaciones manuales en DAX.

---

## 9. Patrón KPI Escalar (uso general)

```dax
KPI_X = 
VAR _f = CALCULATE(MAX(tabla[fecha]), NOT ISBLANK(tabla[col]))
RETURN CALCULATE(MAX(tabla[col]), tabla[fecha] = _f)
```

Este patrón resuelve el problema de que `LASTNONBLANK` y `LASTDATE` se comportan diferente según el contexto de filtro. La medida funciona como **escalar** en tarjetas (retorna el último valor) y como **serie temporal** en gráficos de línea (retorna el valor en cada punto de la fecha) — sin duplicar código.

---

*Última actualización: mayo 2026*
