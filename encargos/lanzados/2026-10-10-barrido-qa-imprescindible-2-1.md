---
esfuerzo: high
---
# Barrido de QA: dejar solo lo imprescindible para la tanda de Jürgen

**Card:** tablero-barrido-de-qa-dejar-solo-lo-imprescindib-d9xa · **Prioridad:** high · Pedido de Jürgen (10-oct 08:07). Se lanza cuando terminen las sesiones de código de la cola.

## Qué se pide
Revisar TODAS las cards in qa del proyecto Yala (`tablero listar --proyecto Yala --todas`) y todos los tickets de `tickets/qa/` en origin/2.1, y decidir por cada uno **done** o **mantener**, con una línea de motivo.

**Pasa a done** si cumple cualquiera de estas condiciones:
- alcanza con el QA ya hecho en simulador o con tests (cita el test o la captura);
- no requiere una validación real de Jürgen;
- es imposible o muy difícil de reproducir a mano;
- es un edge case demasiado remoto.

**Nunca pasa a done**, salvo que ya tenga evidencia fuerte (tests de integración, goldens, prueba de humo en staging o producción, capturas antes y después del flujo real): lo que toca dinero real, migraciones, borrado de datos, la nube con dos dispositivos o compras.

Las cards de «Decidir …» que están en in qa: si la decisión ya está tomada e implementada, done; si sigue pendiente, mantener y decirlo.

## Cómo
1. No hace falta simulador. Úsalo solo para verificar algo puntual y, si lo usas, respeta la sección de carga.
2. En un solo PR a 2.1, mueve con `git mv` los tickets de `tickets/qa/` a `tickets/done/`, añade en cada uno la línea «Cerrado en el barrido de QA 2026-10: <motivo>» y actualiza `docs/TICKETS.md`.
3. En el mismo cierre, mueve las cards correspondientes a done con `tablero mover <id> --a done --agente frank` y deja el motivo en la nota. Las que se mantienen siguen in qa con jurgen.
4. Entregable: `docs/qa/tanda-qa-jurgen-2.1.md` (y una copia en `~/Claude/entregas/`), con:
   - la **tanda final de Jürgen**, agrupada por lo que necesita: un iPhone, dos iPhone con el mismo iCloud, TestFlight, cuenta Pro e iPad;
   - por cada item: id de la card, título, un guion corto (3 a 6 pasos con el resultado esperado) y los minutos estimados;
   - el **tiempo total estimado**;
   - la **tabla de lo que pasó a done** (id, título y motivo).
5. En el aviso de cierre: cuántas pasaron a done, cuántas quedan y el tiempo total de la tanda.

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cuenta como «evidencia fuerte» para cerrar algo sensible?** → Test de integración contra el código real (store en disco, bridge real, wipe real), XCUITest del flujo real con seam, banco de IA con el modelo de producción y control rojo, o migración de servidor aplicada con humo. Un unit test de tabla pura, solo, no alcanza.
Por qué: es la lista del encargo, aterrizada a lo que este repo produce. Alternativa descartada: aceptar mutantes sobre unit como fuertes; prueban el test, no el flujo.

**D2 · Lo que no se puede provocar a mano (techos de 72 h, fallos inyectados, carreras), aunque toque borrado o migración** → done, si el cambio solo bloquea o aplaza un borrado y lo fija un XCUITest o unit con mutantes.
Por qué: el encargo cierra lo «imposible o muy difícil de reproducir», y un device-QA ahí solo miraría caminos que no cambiaron. Alternativa descartada: mantenerlos; inflaría la tanda sin poder probar nada.

**D3 · Rediseños visuales** → mantener, salvo que Jürgen los aprobara sobre capturas (`group-expense-views-redesign`) o ya los viera en su iPhone (hero de Estadísticas).
Por qué: es validación real suya, de identidad. Alternativa descartada: cerrarlos por tener capturas de simulador que él no aprobó.

**D4 · `adopt-window-uploads-…` (card kyys, «Decidir»)** → ticket y card a backlog, no a done.
Por qué: la decisión A (canario primero) está implementada; la política sigue pendiente y el propio ticket dice que vuelve a backlog. Su device-QA es casi imposible de montar y el número lo dará la flota.

**D5 · `reverse-exit-on-a-reverted-account-rejects-the-retry` está en `blocked` con la card en qa** → pasa a `qa`.
Por qué: su bloqueo (aplicar g17_01) se cumplió el 9-oct; queda solo el device-QA con dos iPhone, que entra en la tanda.

**D6 · Tickets en qa sin card** → no se crean cards; la tanda los lista como «sin card».
Por qué: el encargo solo pide mover cards existentes y crear las de tickets nuevos. Crear 20 sería alcance no pedido.

**D7 · Grupos de la tanda** → los cinco del encargo más «Sin iPhone (consola/ASC)», separando «iPhone de pruebas con Yala Dev → staging» de «TestFlight» (las pruebas con tus datos reales de iCloud solo las ve el contenedor de producción).
Por qué: cada grupo se monta una vez. Alternativa descartada: un solo grupo «un iPhone» de seis horas.

**D8 · PR #427 y #443 en conflicto (DIRTY)** → no se tocan; se anotan.
Por qué: no son de este encargo, y rebasarlos mezclaría su trabajo con un barrido de documentación.
