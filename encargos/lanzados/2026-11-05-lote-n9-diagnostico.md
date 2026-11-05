# Lote N9 · Diagnóstico de nube
toca: `MetricsSpool.swift`, `CloudSyncDebugView.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador si hace falta (pipeline serial).
Lote nube (cola-2-3-propuesta.md §3 N9). La card de medir Activar la nube en TestFlight la deja Jürgen; no la implementes como medida en su iPhone.

Cards:
1. Con la cola de métricas llena, un envío puede borrar canarios del Modo Nube que nunca salieron.
2. El panel de depuración de la nube dice «red 0» cuando no debería.
3. «Activar la nube» con pocos datos tarda minutos: falta medir en qué paso — solo deja hooks/canarios de medición listos; no pidas TestFlight ni despiertes a Jürgen de noche.

Hecha cuando: 1 y 2 hechas; 3 deja instrumentación usable. Tests en verde.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · Rama base** → `origin/2.3` (el worktree nació de `2.2`; se re-apuntó antes de tocar nada). PR contra `2.3`.
Por qué: el encargo dice «Rama base: 2.3». Alternativa descartada: `2.2`, que no es la versión del lote.

**D1 · Cómo se identifica lo que viajó en la purga de métricas** → identidad LOCAL por evento en el spool (`MetricsSpoolEntry {id, event}`), que no viaja; la purga retira por `id`. El formato viejo (`[MetricsEvent]`) se lee y se le asigna identidad al vuelo.
Por qué: el wire no cambia (el gateway no necesita despliegue) y una actualización no tira la cola. Alternativa descartada: un campo `id` en `MetricsEvent`, que viajaría al gateway sin uso.

**D2 · Qué dice el panel en las fases previas al montaje de la vuelta** → «red n/a (vuelta: ver «Techo vuelta»)» y una fila nueva «Techo vuelta» con fase sellada, desde cuándo, cuánto lleva parada (mismo cálculo que el runner) y los relojes de causa y de motivo definitivo. Fuera de esas cuatro fases, «red N» como siempre (la ida sigue usando el contador).
Por qué: es lo que pide el ticket y el panel es solo DEV. Lógica pura en `Yala/App/Logic/CloudSyncDebugReverseClockLogic.swift` (fuera del `#if DEV_BUILD`) para que los unit tests, que corren con el scheme `Yala`, la vean.

**D3 · Qué instrumentación deja la card 3** → `cloudMigrationStep` y `cloudMigrationImportWaited` ya existen (miden pasos y la espera a iCloud). Falta poder separar la hipótesis 2 (la subida cuenta todas las filas): un canario nuevo por página confirmada de la subida de la ida, `cloudSnapshotPageUploaded` (`detail` = `<tabla>|<filas>`, `x` = segundos de la página). Más el arreglo de la card 1, que evita perder canarios con la cola llena. Sin pedir TestFlight ni medir en iPhone (lo deja Jürgen). La card queda en backlog con «instrumentación lista» y la guía de lectura en su ticket.
Por qué: con pasos + espera + páginas, una sola activación dice qué paso se lleva el tiempo y, si es la subida, qué tabla. Alternativa descartada: persistir el reloj de pasos entre relanzamientos (el hueco medido es antes del corte, donde no se relanza).

**D4 · Review adversarial** → no. Telemetría y panel DEV: un bug aquí no mueve datos de la persona.
