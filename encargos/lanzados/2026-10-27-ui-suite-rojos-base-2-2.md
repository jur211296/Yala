---
esfuerzo: high
---
# S11f · Cinco XCUITest en rojo en la punta de 2.2 (base)

## Qué hay que hacer
Investigar y arreglar (o abrir tickets con causa medida) los XCUITest rojos de la suite que fallan en la punta de 2.2 sin relación con «Cómo usas Yala».

## Contexto
Gate de PR #649: 7 rojos en `YalaUITests`. 6 fallan igual en la base. El de Novedades lo cubre `whats-new-2-2-review-before-release`. Ticket: `ui-suite-2-2-five-tests-red-on-the-base`.

## Qué se pide
- Medir causa de los cinco restantes.
- Arreglar en esta sesión o abrir ticket por causa.
- La sesión **termina con `/cerrar-total`**.

## Cómo se sabe que está bien
Los cinco verdes en la punta de 2.2, o cada uno con ticket y causa medida.

Cards: `tablero-cinco-xcuitest-en-rojo-en-la-punta-de-2-l4g1`. Versión 2.2. Base `origin/2.2`. Al cerrar, card a in qa asignada a jurgen con guion de iPhone si hace falta QA manual; si no, a done.
Cierre: cierra sola con `/cerrar-total` salvo decisión vital (fuerza mayor, seguridad o diseño crítico).

## Pie pipeline
- Una sesión Yala a la vez. Rebase único antes del PR (gate después del CI del PR anterior).
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Un rojo que depende del día en que corre («Lo que te falta pagar»): ¿se toca el cálculo o el test?** → El test:
se lanza con el seam que ya existe `-uitest-scheduled-due-today` (un pago que vence hoy). La pregunta de producto
—«Este mes» cierra hoy y la sección deja fuera los pagos de los días que quedan del mes— va a un ticket propio.
Por qué: cambiar qué suma una cifra financiera es decisión de Jürgen, y el encargo es la suite. Alternativa descartada:
ampliar el intervalo de pendientes al fin de mes en esta sesión (cambia la cifra que ve el usuario sin que nadie lo decida).

**D2 · Un rojo porque el texto cambió por una decisión ya tomada** («Gustos y caprichos.» → «…: salidas, delivery.»,
lote 2 · B del 23-oct) → se actualiza el test al texto vigente. Por qué: el producto está bien; el test se quedó atrás.

**D3 · Los otros tres (chat, duplicados, Observaciones sin consentimiento)** → medir antes de decidir: causa del test
→ se arregla el test; bug de producto pequeño e inequívoco → se arregla con su test en rojo antes; si pide decisión de
producto → ticket con la causa medida. Por qué: es lo que pide el «Hecho cuando» del ticket.

**D4 · Novedades (`WhatsNewLaunchUITests`)** → fuera: lo cubre `whats-new-2-2-review-before-release`.

**D5 · Capturas** → solo si algún arreglo cambia lo que se ve; un cambio solo de tests no lleva capturas.

**D6 · Card al cerrar** → `done` si nada pide el iPhone; ticket `ui-suite-2-2-five-tests-red-on-the-base` a `done`
cuando cada uno de los cinco esté verde o tenga su ticket.
