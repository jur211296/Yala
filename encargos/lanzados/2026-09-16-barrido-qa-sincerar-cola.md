# Barrido /qa: sincerar tickets/qa/ — qué necesita Jürgen, qué no, lo no replicable a done

## Contexto
Jürgen (2026-09-16 ~09:20 Lima): quiere sincerar la lista de QA. Hay ~83 tickets en `tickets/qa/`. El skill es `/qa` (`.claude/commands/qa.md`), modo lote.

**Override explícito de esta sesión** (rompe la regla habitual del skill «no cierres por inferencia»):
lo que **no sea replicable ni testeable** (ni en simulador ni con un guion razonable de device) → **directo a `tickets/done/`**, con nota clara de por qué. Objetivo: lista honesta, no acumular humo.

## DIURNO (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen si hace falta decisión de producto o acceso.

## Que se pide
1. Empieza con `/qa` (lote sobre `tickets/qa/`). Disco: `bash qa/scripts/disk-report.sh --guard`. Simulador integrado Claude Code + XcodeBuildMCP, scheme **Yala Dev**, iPhone 17 Pro. Seeds/`UITestHooks` cuando ayuden.
2. Por cada ticket, clasifica y actúa:
   - **Simulable** → reproduce, captura evidencia. **PASS solo si lo viste en pantalla** → `done` + `qa-status: passed`. **FAIL** → `in-progress` + notas; **no arregles** dentro de `/qa`.
   - **Necesita Jürgen / device** (TestFlight, multi-dispositivo, SIWA/Google real, APNs, StoreKit real, `YALA_DEV_SHARED_SECRET`/staging, dos teléfonos, Attest real, etc.) → **déjalo en `tickets/qa/`** y anótalo en la lista «cola física / Jürgen». No es FAIL.
   - **No replicable / no testeable** (sin guion razonable en sim ni en device; o el ticket ya no aplica; o solo era rastro Console sin superficie) → **`tickets/done/`** con `qa-status`/`qa-notes` explicando el cierre por no replicable (override Jürgen 2026-09-16). Actualiza frontmatter y `docs/TICKETS.md`.
3. Al cerrar el lote: tabla ticket · veredicto (PASS / FAIL / device-Jürgen / done-no-replicable) · qué se vio o por qué.
4. Separar bien las cuatro cubetas; no mezclar FAIL con «necesita device».
5. Gate/commit del board+evidencia, PR si aplica, merge a 2.1, `/cerrar-total`. Bugs de producto encontrados → ticket en backlog (`--solo-crear`), no los arregles aquí salvo higiene del board.

## MODO AUTÓNOMO HASTA TERMINAR
Board, `docs/TICKETS.md`, commits, merge, `/cerrar-total` sin preguntar por gate/commit. Solo parar ante decisión/acceso real. UI tests CI advisory.

## Que NO
- marketing/
- `agent-device`
- Declarar PASS por lo que dice el código (salvo el bucket «done-no-replicable», que es cierre explícito sin PASS visual)
- Auto-lanzar otra sesión de producto después

## Como se sabe que esta bien
Lista de `tickets/qa/` sincerada: solo queda lo que de verdad necesita sim pendiente o Jürgen/device. Tabla del lote + board al día + `/cerrar-total`.

## Avisos Frank
Webhook Mini (URL/key local, no en git) cuando: (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` con resumen de usuario (tabla + cola física restante); (4) sin siguiente — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Escrito a mitad de ejecución (el freno saltó al crear el primer ticket de backlog); D1-D7 ya se estaban aplicando.

**D1 · Qué cuenta como «no replicable» para cerrar por el override** → solo tres casos: no hay guion ni en simulador (con los seams que existen) ni en un iPhone con el acceso de Jürgen (TestFlight, dos teléfonos, staging, wrangler); el estado de partida ya no puede producirse; o lo pendiente era solo un rastro de consola sin nada que ver en pantalla.
Por qué: es la letra del encargo. Alternativa descartada: cerrar lo «largo» o «caro» de montar, que es precisamente la cola de Jürgen.

**D2 · Cómo se marca un cierre sin PASS visual** → `status: done`, `qa-status: not-replicable` y `qa-notes` citando «override Jurgen 2026-09-16». Si todo lo pendiente vive en otro ticket que sigue abierto, `qa-status: absorbed` y la nota lo nombra.
Por qué: quien busque «qué se cerró sin verse» no debe confundirlo con lo que se verifica en otro sitio. Alternativa descartada: un solo valor para las dos cosas.

**D3 · Ticket con una parte PASS y otra no replicable** → `done` con `qa-status: passed` y `qa-notes` que nombra la parte cerrada sin verificar.
Por qué: dejarlo en qa por lo imposible es el humo que el encargo quiere quitar. Alternativa descartada: partirlo en dos tickets.

**D4 · Ticket con una parte PASS y otra que sí necesita device o manos** → sigue en `qa`, con «QA Visual — parcial» y el guion de lo que falta.
Por qué: moverlo sería declarar PASS de algo que nadie vio.

**D5 · PASS de sesiones anteriores que se quedaron en qa** → se re-verifican hoy en simulador antes de moverlos. No se hereda un PASS.
Por qué: la regla «mide antes de obedecer a un documento».

**D6 · Intents vistos desde Atajos, sin la voz ni el disparador de Wallet** → cuentan como PASS cuando el recorrido de punta a punta se vio en pantalla (`storekit-appgroup-siri-pro-gate`, `siri-intent-dual-container`). La voz llega al mismo `perform()`. Apple Pay no entra: sus parámetros no se pueden automatizar y el caso (d) necesita iCloud real.
Por qué: pedirle a Jürgen que hable con Siri para ver el mismo diálogo no aporta nada. Alternativa descartada: dejar los dos en la cola de device. **Es la decisión más discutible del lote.**

**D7 · Build `Debug` sin `DEV_BUILD` como montaje** (kill-switch abajo, canal de Grupos apagado) → evidencia válida: bajo `-uitest`, los flags remotos valen su default de producción.
Por qué: es la única forma de ver esas pantallas en simulador sin tocar staging.

**D8 · Tickets que esperan código, un seam o una decisión** → a `backlog` o `blocked` con una nota, nunca a `done`.

**D9 · Hallazgos** → los defectos de producto van a backlog, después de buscar duplicados, y no se arreglan aquí. Los artefactos del montaje sin efecto para el usuario (el «$» de los widgets bajo `-uitest`, el bucle de la hoja con sesión falsa) no llevan ticket.

**D10 · La cola física** → se reescribe `qa/guion-tanda.md` con **todo** lo que queda en qa, agrupado por montaje. El punto 1 de `qa-guion-tanda-no-cubre-17-tickets` queda hecho; el 2 (el checker) sigue abierto.
Por qué: un guion con la mitad de la cola es cómo se pierden tickets. Alternativa descartada: dejar la lista solo en el PR.

**D11 · Guiones caducados** → nota fechada al final del ticket, sin reescribir el guion original.
Por qué: conserva por qué cambió. Alternativa descartada: editar el guion sin dejar rastro.

**D12 · Entrega** → rama y PR. El diff son docs, tickets y evidencia, así que el gate es la validación del índice más `validate-coverage`. Mergeo yo, como autoriza el encargo, y luego `/cerrar-total`. La trampa de Atajos en simulador (sin firma de equipo, `linkd` rechaza la tarjeta de la app) va a `docs/aprendizajes-tecnicos.md`: le sirve a cualquier QA futuro.
