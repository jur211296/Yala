Yala
# Arreglar las pruebas inestables de la caché de divisas (y la del tablero en storeRemoteChange)
---
toca: Yala/Services/CurrencyConverter.swift,YalaTests/CurrencyConverterLatestRateArrivalTests.swift,YalaTests/CurrencyConverterRowMemoTests.swift,YalaTests/CurrencyConverterCacheTests.swift,YalaTests/CurrencyConverterDailyFactorsTests.swift,YalaTests/CurrencyConverterLatestRateQualityTests.swift,YalaTests/CurrencyConverterPartialRateTests.swift,YalaTests/CurrencyConverterTests.swift,tickets/done/2026-11-17-verificacion-p1-divisas-inestables.md
esfuerzo: high
cierre: cierra-sola
---

## Qué hay que hacer (P1, primera parte)
En dos semanas hubo 65 rescates «Rescatado al repetirlo» en el job `tests`; 60 son de la familia `CurrencyConverter*` (`CurrencyConverterLatestRateArrivalTests` 39 en tres casos, `CurrencyConverterRowMemoTests` 16). Un rojo rescatado no es verde.

- Encuentra la causa raíz (estado compartido, caché estática, orden, reloj, concurrencia) con `systematic-debugging`; no subas tiempos de espera ni metas reintentos.
- Arréglala en el código o en las pruebas, lo que sea la causa real. Si el arreglo es en `CurrencyConverter.swift`, que no cambie comportamiento de producción salvo que sea un bug real; si lo es, dilo en el cierre.
- Prueba de que quedó: corre la familia entera muchas veces seguidas (al menos 50 repeticiones, en paralelo como en el CI) sin un solo rojo, y deja el número en el PR.
- En el mismo lote: la card «Unit inestable: storeRemoteChange_dropsTheCache cayó una vez en el CI y pasó al reintento». Si está en esta familia o cerca, arréglala igual; si no, mide y deja el diagnóstico en el ticket. Al cerrar, mueve esa card a done si quedó arreglada.
- Ticket en `tickets/done/2026-11-17-verificacion-p1-divisas-inestables.md`.

## Contexto
Propuesta de verificación del 17-nov (comparación con el equipo de Claude Code), aprobada por Jürgen el 17-nov: «Apliquemos todo lo recomendado». Fuente en `origin/2.3`: `docs/verificacion/README.md` y `docs/verificacion/propuesta-2026-11-17.html` (array `PROPUESTAS`). Artículo de referencia: https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ . Lee la propuesta correspondiente entera antes de empezar; las mediciones de ahí son tu punto de partida, pero vuelve a medir lo que cambies.

## Reglas
- Commits y PR sin firma de IA. PR hacia `2.3`. Rama desde `origin/2.3`; justo antes del PR, `git fetch` y un solo rebase.
- Dependencias: la sesión arranca sobre `origin/2.3`, sin esperar CI ni merge del PR anterior; solo espera el merge si toca los mismos archivos o necesita el código de otra sesión (se indica abajo cuando aplica).
- `toca:` acotado: si necesitas tocar un archivo fuera de la lista, anótalo en el cierre con el motivo.
- Simuladores: en la Max puedes usar un segundo simulador si otra sesión ocupa uno (tope 2); también el iPhone 14 conectado por DeviceMCP.
- Nada de reglas, scripts ni workflows del gate que se lean del propio PR cuando la propuesta dice «leído de 2.3»: se leen de `origin/2.3`.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas. Lo vital (accesos, credenciales, seguridad, ruleset distinto de lo aprobado, minutos de runner fuera de lo razonable) se pregunta, no se asume. Semi 05:30–20:00: preguntas y esperas con la sesión viva. Nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto.
- Si el trabajo queda completo y el modo lo permite, termina con `/cerrar-total`.
- Entregable: artifact visual de Claude (antes/después, qué se midió, qué queda en observar y cuándo se promueve).
- El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada», y una sección «Lección» si hubo un error evitable.

## Paso 0 — decisiones (resueltas en semi por Frank, 2026-11-17)

1. **Causa antes que arreglo.** Medido en el CI: los 17 rescates de las últimas 120 corridas caen en el control «la caché está llena» (o «sigue lo leído»), y el aviso que la vacía es `.NSPersistentStoreRemoteChange` desde «otro hilo». Las suites corren en serie: hipótesis = eco asíncrono del propio `save()` del fixture. Se mide con una sonda local antes de tocar código.
2. **Producción no cambia de comportamiento** salvo que la medición destape un bug real: retirar la caché con cualquier aviso es una decisión documentada (`currency-fx.md`). Un seam de test, si hace falta, no altera el camino de producción.
3. **Nada de subir esperas ni reintentos**: la ventana sucia de `RowMemoTests` (5 intentos) se sustituye por la causa, no se amplía.
4. **Prueba**: la familia `CurrencyConverter*` ≥ 50 repeticiones seguidas (`-test-iterations`), sin un rojo; número en el PR.
5. **`storeRemoteChange_dropsTheCache`** está en la familia: se arregla aquí y su card va a done.
6. Fuera de `toca:` solo lo imprescindible, anotado en el cierre.
