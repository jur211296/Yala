# Barrido de QA 2.2: dejar en QA solo lo que necesita a Jürgen — card fzmv

## Contexto
Card: `tablero-barrido-de-qa-2-2-dejar-en-qa-solo-lo-qu-fzmv` (high, cierra-sola, 2.2, in progress).
Hay muchas cards en «in qa». Esta sesión revisa cada una y verifica en el simulador o con tests lo que se pueda sin Jürgen; esas pasan a `done` con nota de evidencia. En QA quedan solo las que necesitan iPhone real, TestFlight, sandbox o juicio de Jürgen, cada una con un guion breve de qué probar.

Base: `origin/2.2`. PRs #615 y #616 pueden estar en cola de auto-merge: justo antes del gate de build/sim, mira si siguen en CI; si siguen, espera a que entren y rebasea una sola vez con el simulador apagado; si 2.2 no se movió, sigue; si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez.

Pipeline serial (1 sim): limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 → verificar → apagar/erase. Al cerrar: DerivedData de ESTE worktree y cachés XcodeBuildMCP de worktrees inexistentes; no preguntes. Disco: mira `df -h /` antes de compilar (ahora ~32 GB libres).

## Que se pide
1. Lista todas las cards Yala en `in qa` (`tablero listar --proyecto Yala`).
2. Para cada una: lee nota/contexto/hechaCuando; decide si se puede verificar sin Jürgen (sim, unit/UI tests, lectura de código + evidencia).
3. Si sí: verifica, mueve a `done` con `--agente frank` y deja en la nota la evidencia (qué corriste, resultado, capturas si aplica). `--nota` reemplaza: copia lo que ya había y añade debajo.
4. Si no: deja en `in qa`, asigna a `jurgen` si no lo está, y añade un guion corto (pasos en el teléfono / TestFlight / sandbox) y por qué no se pudo cerrar sola.
5. No implementes features nuevas ni rediseños; solo verificación y movimiento de cards. Si encuentras un bug claro al verificar, crea card nueva y sigue.
6. Entrega en el PR un resumen (docs o cuerpo del PR): cuántas pasaron a done, cuántas quedan en QA y por qué (tabla).

## Que NO hay que tocar
- No mergees a la fuerza ni toques producción / CloudKit Production / App Store.
- No borres cards; no muevas a done sin evidencia.
- No toques marketing/, ni tmux de otros proyectos (`salud--*`, `sat-lab--*`, etc.).
- En el árbol principal: no toques `Yala.xcscheme`, `encargos/pendientes/`, ni `Cloudkit Schemas/yala_dev-*.ckdb`.

## Como se sabe que esta bien
- Cada card que estaba en QA tiene nota que dice si necesita a Jürgen y por qué, o evidencia de cierre.
- Las verificables sin Jürgen están en `done`.
- PR a 2.2 con el resumen; card fzmv a `done` (o `in qa` solo si el propio barrido pide ojo humano, con guion).
- Cierra con `/cerrar-total`. Mini limpia.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cuenta como evidencia para pasar una card a done?** → Un test que corre HOY sobre `origin/2.2` (unit o XCUITest) y fija lo que pide el hechaCuando, o una prueba a mano en el simulador con captura. La evidencia de un PR antiguo sola no basta.
Por qué: el árbol se movió desde cada PR; un verde de hace días no dice nada del árbol de hoy. Alternativa descartada: cerrar por «el PR traía tests», sin correrlos.

**D2 · Una card cuya única prueba restante ya vive en otra card que se queda (p. ej. L19-3 dentro de su card de despliegue, L15-8 dentro de la prueba de Apple Pay)** → Se cierra con su evidencia local y la comprobación viaja en el guion de la otra.
Por qué: dos cards para un mismo gesto en el teléfono duplican la tanda. Alternativa descartada: dejar las dos en QA.

**D3 · Card en QA cuyo arreglo ya falló en el iPhone y no tuvo segunda vuelta (n5zw)** → Sale de QA a «lista para lanzar», asignada a Frank.
Por qué: repetir la prueba daría el mismo fallo; lo que falta es trabajo, no QA. Alternativa descartada: dejarla en la tanda de Jürgen.

**D4 · Compras (renovar, comprar, caducar)** → Se quedan las tres que dependen de la transacción real del sandbox (7c97, fleb, u5pi); las de presentación del lote Pro (L17-7, L17-8, L16-11, «1 mes») se cierran con XCUITest.
Por qué: 7c97 demostró que el sandbox de Apple se porta distinto del seam del simulador; la presentación no depende de eso.

**D5 · Campos nuevos de iCloud (qp67, ax7s)** → Se quedan: necesitan el despliegue del esquema (cards de Jürgen) y dos iPhone.
Por qué: lo único que falta probar es el viaje por iCloud de un campo nuevo, y eso no se monta en el simulador.

**D6 · Cards de Lola (b4es, eukp)** → No se tocan.
Por qué: son de marketing, fuera de mi territorio.

**D7 · Entrega** → Doc `docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-24.md` con las dos tablas, tickets de las cards cerradas a `tickets/done/`, PR a 2.2 en cola de auto-merge.
