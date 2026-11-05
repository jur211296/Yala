# Lote N8 · Divisas
toca: `EntityApplyMap.swift`, `CurrencyConverter.swift`, `CurrencyUtils.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial: limpiar → build -jobs 2 sin sim → boot 1 → tests → apagar).
Lote nube chico (cola-2-3-propuesta.md §3 N8). Review adversarial: toca cálculo financiero. Sin decisiones pendientes.

Cards:
1. Cambiar la divisa de una cuenta en un teléfono puede dejar el otro con movimientos en la divisa vieja.
2. Convertir importes de otra fecha hace un fetch de tasas por llamada.
3. Una cuenta cuyo saldo suma cero sale como «€ -0.00» en Cuentas.

Hecha cuando: las tres quedan hechas, tests relevantes en verde, `/gate` que aplique pasa. No toques MigrationRunner ni Activar la nube.

Restricciones: PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total. DerivedData/cachés de esta sesión al cerrar, sin preguntar.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Base: la rama nace de `origin/2.3` (el worktree nació sobre 2.2; se movió antes del primer cambio). PR contra 2.3.

**D1 · Card «-0.00»: ¿dónde se quita el signo?** → En el formateo, comparando lo que el MISMO formateador escribe para
el valor y para el cero (`CurrencyFormattingHelper.isShownAsZero`). El saldo no se redondea.
Por qué: el número sigue exacto para los cálculos (ajustes de saldo, comparaciones); solo cambia lo que se pinta, y vale
para cualquier número de decimales y modo de redondeo. Alternativa descartada: redondear la suma en
`AccountBalanceCalculator`, que cambia un dato que otros comparan.

**D2 · Card «-0.00»: ¿qué sitios?** → El formateador central (lo usan `AmountText`, los saldos del Panel y la foto de
los widgets), la lista de Ajustes › Cuentas (formateador propio, el sitio medido), el formulario de cuenta (saldo y
ajuste), el campo del saldo inicial del flujo de caja, el partidor de importes de los widgets, la cifra de la pantalla
bloqueada y las celdas compactas. También el «+0.00» con signo forzado. Fuera: etiquetas de eje de gráficas (las marcas
son valores exactos) y los porcentajes.

**D3 · Card de tasas: ¿qué se cachea y cuándo se invalida?** → Las filas de tasas ya decodificadas por fecha (la del
día y la lista de anteriores), dentro del converter, vivas solo durante una vuelta del hilo principal (una pasada de
cálculo) y retiradas antes con `.yalaExchangeRatesUpdated`, con cualquier guardado que toque `ExchangeRate`, con un
cambio remoto del store y al cambiar de contexto. `rateFactors` no se toca (ya lee en bloque).
Por qué: la fila del día la escriben también el espejo de iCloud y el pull del Modo Nube, que no postean la
notificación; una caché que solo se invalidara con ella taparía una fila mejor recién llegada — el bug de siempre de
este módulo. Acotada a la pasada, el peor caso es el de hoy. Alternativa descartada: caché global hasta la
notificación.

**D4 · Card del receptor (cambio de divisa en otro teléfono): ¿qué hace el receptor?** → **Pendiente de confirmar con
Jürgen** (se pregunta a las 5:00, regla nocturna). El ticket dice «el receptor no re-expresa el histórico local»
(decisión 2A) como «lectura por confirmar antes de implementar», y medido en el código queda un caso que esa lectura no
cubre: las filas propias del receptor que el otro teléfono no conocía al convertir se quedan en la divisa vieja para
siempre. Mientras llega la respuesta: medición de la ventana por orden de llegada y test del receptor con histórico
propio, sin cambiar su comportamiento.

**D4 resuelta (2026-11-05, respuesta del bot de Jürgen antes de las 5:00)** → **opción C**: la cifra de la cuenta
(`AccountBalanceCalculator`) convierte al pintar, a la tasa de su fecha, las filas que quedaron en otra divisa que la
de su cuenta, sin tocar lo guardado. Reversible. Descartadas A (la cifra mentía) y B (el receptor no distingue lo que el
emisor ya convirtió de lo que no conocía). Elegida por el bot de noche como la recomendada y reversible.
