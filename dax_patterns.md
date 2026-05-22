# DAX Patterns — Guía de Arquitectura de Medidas

Este documento no lista todas las medidas del modelo (son 99). Documenta los **4 patrones arquitectónicos** que resuelven problemas reales de Power BI y se reutilizan consistentemente en todo el dashboard.

---

## Patrón 1 — KPI Escalar Dual-Use

**Problema**: Las funciones estándar (`LASTNONBLANK`, `LASTDATE`) se comportan diferente según el contexto de filtro. Una medida que devuelve el último valor en una tarjeta rompe cuando se coloca en un gráfico de líneas — devuelve el mismo valor para todos los puntos.

**Solución**: Calcular explícitamente la última fecha con dato y usar esa fecha como filtro:

```dax
KPI_X =
VAR _f = CALCULATE(
    MAX(tabla[fecha]),
    NOT ISBLANK(tabla[columna])
)
RETURN CALCULATE(
    MAX(tabla[columna]),
    tabla[fecha] = _f
)
```

**Por qué funciona en ambos contextos**:
- En una **tarjeta**: no hay filtro de fecha activo → `_f` = última fecha con dato → retorna ese valor único.
- En un **gráfico de líneas**: hay un filtro de fecha por cada punto de la serie → `_f` = última fecha con dato *dentro de ese contexto* → como la fecha del contexto es la misma que `_f` para cada punto, retorna el valor de esa fecha.

**Resultado**: Una sola medida funciona como escalar en tarjetas **y** como serie temporal en gráficos, sin duplicar código.

**Medidas que usan este patrón**: `KPI_IMAE_Var_Int`, `KPI_Inflacion_Interanual`, `KPI_TC_Actual`, `KPI_RIN_Actual`, `KPI_Credito_Actual`, `KPI_TCR_Actual`, `KPI_Spread_CP`, `KPI_Spread_LP`, `KPI_LDR_Actual`, y más.

---

## Patrón 2 — Centrado en Umbral (Zone Centering)

**Problema**: Power BI dibuja áreas de zona siempre desde el baseline de 0. Si el umbral de alerta está en 75% y el valor está en 78%, el área "de riesgo" no parte del 75% — parte del 0%, saturando el visual y perdiendo la lectura.

**Solución**: Restar el umbral a la serie principal. El eje queda centrado en 0 = umbral. Las zonas se dibujan simétricamente alrededor del punto de interés.

```dax
-- Ejemplo: LDR con umbral en 75%
LDR_vs_Umbral = [LDR_Serie] - 0.75

-- Zona de eficiencia: activa cuando LDR está SOBRE el umbral
LDR_Zona_Eficiente_v2 =
VAR _ldr = [LDR_Serie]
RETURN IF(_ldr >= 0.75 AND _ldr <= 0.85, _ldr - 0.75, BLANK())

-- Zona de riesgo: activa cuando LDR está SOBRE 85%
LDR_Zona_Riesgo_v2 =
VAR _ldr = [LDR_Serie]
RETURN IF(_ldr > 0.85, _ldr - 0.75, BLANK())
```

**El mismo patrón aplicado a Brecha PPA** (umbral = 0):
```dax
-- La brecha ya está centrada en 0 por definición (NIC - desl - USA)
Brecha_PPA_Zona_Presion =
IF([Brecha_PPA_Serie] > 0, [Brecha_PPA_Serie], BLANK())

Brecha_PPA_Zona_Deflacion =
IF([Brecha_PPA_Serie] < 0, [Brecha_PPA_Serie], BLANK())
```

**Medidas que usan este patrón**: `LDR_vs_Umbral`, `LDR_Zona_Eficiente_v2`, `LDR_Zona_Riesgo_v2`, `Brecha_PPA_Zona_Presion`, `Brecha_PPA_Zona_Deflacion`, `IMAE_Zona_Expansion`, `IMAE_Zona_Contraccion`.

---

## Patrón 3 — Buffer Visual (Near-Miss Storytelling)

**Problema**: El peso del SPNF en el crédito total nunca cruzó el umbral del 20%, por lo que una zona que se activa "cuando supera el umbral" queda vacía toda la serie. La historia es el *acercamiento* al umbral, no el cruce.

**Solución**: Calcular el espacio restante entre la serie y el umbral, y apilarlo visualmente. El "sliver" que queda entre la barra y el techo se comprime cuando el valor se acerca al límite.

```dax
Crowding_Buffer =
VAR _peso = [Peso_SPNF_Serie]
RETURN IF(NOT ISBLANK(_peso), 0.20 - _peso, BLANK())
```

**Implementación**: `Peso_SPNF_Serie` + `Crowding_Buffer` como columnas apiladas en un gráfico de "líneas y columnas apiladas". La suma de ambas siempre llega a 20% — el umbral es el techo visual, no una línea separada.

**Lectura**: En 2018–2020, el sliver naranja (buffer) casi desaparece. En 2025, se ensancha de vuelta a ~6pp. La historia se lee sin que el umbral se cruce jamás.

---

## Patrón 4 — Estado Semáforo vía Medida Numérica

**Problema**: El formato condicional en Power BI no acepta medidas de texto directamente como regla de color. Se necesita un valor numérico que mapee a un color.

**Solución**: Crear dos medidas por cada semáforo: una de **texto** (para mostrar) y una **numérica** (para el formato condicional de color).

```dax
-- Medida de texto (va en la tarjeta)
Estado_Macro_Actual =
VAR _imae  = [KPI_IMAE_Var_Int]
VAR _infl  = [KPI_Inflacion_Interanual]
RETURN
SWITCH(TRUE(),
    _imae >= 0.035 && _infl <= 0.03, "Expansión con anclaje",
    _imae >= 0.035 && _infl >  0.03, "Expansión con presión",
    _imae <  0.035 && _infl <= 0.03, "Desaceleración controlada",
    _imae <  0.035 && _infl >  0.03, "Estanflación",
    "Sin datos"
)

-- Medida numérica gemela (va en "Formato condicional → Valor del campo")
Estado_Macro_Valor =
VAR _imae  = [KPI_IMAE_Var_Int]
VAR _infl  = [KPI_Inflacion_Interanual]
RETURN
SWITCH(TRUE(),
    _imae >= 0.035 && _infl <= 0.03, 1,   -- Verde
    _imae >= 0.035 && _infl >  0.03, 2,   -- Amarillo
    _imae <  0.035 && _infl <= 0.03, 3,   -- Naranja
    _imae <  0.035 && _infl >  0.03, 4,   -- Rojo
    0
)
```

**En Power BI**: La tarjeta muestra `Estado_Macro_Actual`. El formato condicional de fondo (o del texto) apunta a `Estado_Macro_Valor` con reglas numéricas: 1 = verde, 2 = amarillo, etc.

**Pares de medidas que usan este patrón**:
- `Estado_Macro_Actual` / `Estado_Macro_Valor`
- `Estado_Anclaje_PPA_Texto` / `Estado_Anclaje_PPA_Valor`
- `Estado_LDR_Texto` / `Estado_LDR_Valor`
- `Indicador_Status_TCR` (variante — texto con emoji, sin gemela numérica)

---

## Nota sobre la Tabla de Medidas

Todas las medidas viven en la tabla `_Medidas` (prefijo guión bajo). Esto es un requerimiento del conector MCP de Power BI Modeling utilizado durante el desarrollo — el prefijo garantiza que la tabla aparezca en la cima del panel de datos y que las operaciones MCP la identifiquen correctamente como tabla de medidas pura.

Las medidas están organizadas en 5 carpetas de visualización (`displayFolder`): `H1_VisionMacro`, `H2_Inflacion`, `H3_SistemaFinanciero`, `H4_TasasCredito`, `H5_RiesgoEstabilidad`.

---

*Última actualización: mayo 2026*
