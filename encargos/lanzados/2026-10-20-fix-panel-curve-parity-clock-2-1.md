# Hacer determinista el unit test de paridad de la curva del Panel (bloquea el PR #567)

Card: «Unit test de paridad de la curva del Panel en rojo según la hora (bloquea el PR #567)» (tablero-unit-test-de-paridad-de-la-curva-del-pan-xzb7).

## Contexto
El check `tests` del PR #567 (solo docs, base 2.1) falla de forma determinista (3 reintentos) en
`PanelBalanceFigureCurveParityTests/everyPastPoint_isThatDaysBalanceAtThatDaysRate` (perfil `.realista`, línea 140):
el primer punto pasado usa la tasa de hoy (66718.85) en vez de la de ese día.
Run: https://github.com/jur211296/Yala/actions/runs/39378333292
Hipótesis: el test depende del reloj (borde de día, zona horaria o tasa del día). Es probable que 2.1 también esté en rojo; no es culpa del PR #567.

## Qué se pide
- Rama desde origin/2.1. Reproducir el fallo (fijando hora/zona: p. ej. cerca de medianoche, UTC vs America/Lima).
- Decidir dónde está el bug real: si el código de la curva/cifra elige mal la tasa del primer día pasado, arreglar el código; si es el test el que usa `Date()`/zona del sistema, inyectar un reloj/calendario fijo.
- El test debe pasar igual a cualquier hora y en cualquier zona. Correr ese suite y los unit tests relacionados del Panel.
- Antes de abrir el PR: `git fetch` + rebase sobre origin/2.1 (solo en ese momento). PR contra 2.1 con el porqué en el cuerpo. No esperar al CI.
- Cerrar con /cerrar-total. Mover la card como toca.

## Qué NO hay que tocar
- Los ficheros sin commitear de ~/Yala (ckdb, xcscheme, encargos, pendientes).
- Los iPhones/iPad de Jürgen.
- Simulador: solo lo que exijan los unit tests; nada de UITests ni QA visual. Si se bootea uno, apagarlo y borrarlo al terminar. Build con `xcodebuild -jobs 2`.
- Borrar al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados, sin preguntar.

## Cómo se sabe que está bien
El test es determinista sin importar el reloj, el fix está en el test o en el código según dónde esté el bug real, y hay un PR abierto contra 2.1.

## Pista (Frank, 20-oct 04:40)
La sesión de la revisión de Yala IA (PR #568, contra 2.2, rama `encargo/2026-10-20-revision-ia-yala-2-2`) ya hizo que este test no dependa del día en 2.2: mira su cambio en `YalaTests/PanelBalanceFigureCurveParityTests.swift` y el ticket `tickets/done/panel-balance-curve-parity-test-depends-on-the-day.md` (`gh pr diff 568`). Parte de ese arreglo y comprueba que encaja en 2.1; si el bug real resulta estar en el código y no en el test, dilo en el PR. No traigas a 2.1 nada más de ese PR.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿El bug está en el código o en el test?** → En el test.
Por qué: la aserción principal (cada punto pasado = saldo de su día × tasa de su día) pasa; solo cae el control final, porque la semilla repite la tasa de hoy en el día 1 (paseo aleatorio redondeado a 2 decimales; replicado: días 20 y 27 de cada mes con `realista`). Alternativa descartada: tocar `BalanceValuation`/`TrendDataProcessor`, que eligen bien la tasa.

**D2 · ¿Reloj inyectado o control construido?** → Control construido: el test sube un 10 % la tasa de la divisa preferida en la fila de ayer y mide el control en el punto de ayer.
Por qué: fijar el reloj entero exige inyectar `now` en producción (`DevSeedService.seed`, `liveBalanceOverride`, `TrendDataProcessor`), que no se pidió. Alternativa descartada: el «algún punto distingue» de #568 — sigue dependiendo del paseo aleatorio.

**D3 · ¿Qué pasa los días 1–3 del mes, cuando «Este mes» no tiene 3 días pasados?** → La aserción se mide también en «Últimos 30 días» (mismo camino, grouping `.day`), y el `#require` de ≥3 puntos va sobre ese periodo.
Por qué: era un segundo rojo por fecha que el encargo no nombraba. Alternativa descartada: cambiar «Este mes» por «Últimos 30 días» (pierde la cobertura del periodo por defecto).

**D4 · ¿Algo más del PR #568?** → No. Solo el criterio; el arreglo es otro y el PR avisa del choque al fundir 2.1 en 2.2.

**D5 · Ticket** → `tickets/done/panel-balance-curve-parity-test-depends-on-the-clock.md` (id distinto del de 2.2 para no chocar al fundir) + fila en `docs/TICKETS.md`.

Sin ADR: nada de esto manda dentro de seis meses.
