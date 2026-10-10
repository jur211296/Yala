# Tras «Volver a iCloud», un movimiento creado en la nube no debe perder su cuenta ni su subcategoría: reproducir y, si se reproduce, arreglar

## Contexto
Card del tablero `tablero-tras-volver-a-icloud-un-movimiento-cread-amad` (high, vence 2026-10-12, bloquea 2.1). Ticket: `tickets/backlog/cloud-tx-epoch-orphan-relations.md`. El triage de tickets del 2026-10-08 lo subió a `high` y dejó este brief.

Lo que vio el usuario (device-QA del 2026-07-17): un movimiento creado mientras la cuenta estaba en la nube (`.cloud`), con cuenta y subcategoría, tras la reversa («Volver a iCloud») quedó sin cuenta y sin subcategoría. Desapareció de Registros (los listados agrupan por cuenta) y solo se encontraba por Buscar. Los 2.311 movimientos anteriores a la época nube quedaron intactos. Nadie lo ha vuelto a mirar desde entonces, y la reversa es función viva de 2.1 (se reescribió media reversa desde julio).

Lo que ya está descartado según el ticket (verifícalo en este árbol antes de apoyarte en ello):
- El eco del pull en `.cloud` estable NO borra relaciones (experimento del 2026-07-17, con kill y relaunch).
- La materialización fresca desde cursor 0 (adopt) resuelve bien las refs.
- La fila de staging llevaba las tres refs (`account_ref`, `subcategory_ref`, `category_ref`) ⇒ la pérdida fue LOCAL, dentro de la ventana de la reversa.
- Los objetos Account/Subcategory nunca se borraron (`healDuplicates`, cascades `.nullify` y borrado+reimport descartados).

Sospechosos que quedan, en orden: (a) un `applyPage` o re-drain dentro de la reversa; (b) la ventana de remount del espejo (export replay + import a la vez sobre un movimiento sin CKRecord previo cuyas relaciones apuntan a records que ya existían); (c) el poco tiempo entre crear y revertir (~4 min en el caso original).

Ficheros implicados (medidos en 2.1 `15b00152c`, verifícalos):
- `Yala/Services/CloudSync/MigrationWorkExecutor.swift`, `MigrationRunner.swift`, `CloudMigrationController.swift`: la reversa y su drain.
- `Yala/Services/CloudSync/SyncApplyEngine.swift` y `EntityApplyMap.swift`: el applier que resuelve `account_ref`, `subcategory_ref` y `category_ref` en relaciones.
- `Yala/Services/CloudSync/EntityEmissionMap.swift`: el emit, que deriva las refs de la relación viva.

Para orientarte: `CLAUDE.md`, `.claude/rules/testing.md`, el ticket entero (incluida la evidencia del Merkle `tx_items`/`inbox_drafts` del 2026-07-18) y, si hace falta, el ADR/H-4 de la reversa en `docs/DECISIONS.md` (solo esa entrada).

## Que se pide
1. Reproducir primero, sin tocar código de producto: simulador limpio con un corpus pequeño → activar la nube contra STAGING (nunca producción) → crear 2-3 movimientos en la nube con cuenta y subcategoría → reversa inmediata (menos de 5 min, como el caso original) y otra variante con espera larga → mirar las relaciones de esos movimientos tras la reversa y tras matar y reabrir la app. Si la repro de extremo a extremo con nube real no es viable en el simulador, intenta reproducir lo mismo con un test de integración sobre el camino de la reversa (crear movimiento en `.cloud` → reversa → comprobar relaciones), y di qué variante usaste.
2. Si se reproduce: sube el ticket a `very-high`, encuentra la causa siguiendo los sospechosos en orden, arréglala y añade un test que crea un movimiento en `.cloud`, ejecuta la reversa y comprueba que `account` y `subcategory` siguen puestos. El test tiene que salir rojo con el arreglo revertido (deja constancia del control rojo).
3. Si NO se reproduce en N intentos: deja escrito en el ticket con qué build, cuántos intentos y qué variantes se probaron; baja el ticket a `medium` y deja una guardia (test de regresión del camino crear-en-nube → reversa → relaciones intactas) para que no vuelva en silencio.
4. Review adversarial del cambio antes del PR: es sync y datos del usuario.
5. Si queda algo que Jürgen deba comprobar en un iPhone real, deja el guion de device-QA en `tickets/qa/`. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree con rutas absolutas en el cierre; si no hay cambio visible, sin capturas.
6. Anota la repro y su resultado en el ticket y muévelo según las convenciones del repo (`tickets/done` o `discarded`, o `qa` si queda device-QA).
7. Cierre: `/cerrar-total` autónomo, sin preguntar (PR a 2.1 con auto-merge, limpieza de la Mini). Al cerrar, mueve la card `tablero-tras-volver-a-icloud-un-movimiento-cread-amad` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- Producción: ni datos, ni backend, ni cuentas reales. Solo staging.
- Lo que no sea el camino de la reversa y la resolución de refs: no refactorices el applier ni el emit más allá del arreglo.
- Los otros tickets `reverse-*` abiertos: si encuentras algo de ellos, anótalo en su ticket, no lo arregles aquí.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Decisiones: la sesión cierra sola. Solo se para a preguntar a Jürgen ante una decisión de producto de verdad (no técnica ni reversible). Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, esa decisión se pregunta con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~30 GB libres el 2026-10-08 a las 17:50, por debajo del umbral de 32) y la Mini se cayó hoy con carga alta: no apiles procesos pesados.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests. No build con sim booteado, no tests mientras compila, no dejar el sim vivo al terminar.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #405 (groups-stats-no-deduplica-gastos, auto-merge a 2.1) sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

Cierre con la Mini limpia: apaga y borra el simulador que usaste, quita DerivedData de la sesión y no dejes worktrees ni Devices huérfanos. Si creaste algún secreto en el Llavero, dilo en el cierre.

## Como se sabe que esta bien
- Repro escrita en el ticket con su resultado (se reproduce / no se reproduce en N intentos, con build y variantes).
- Si hubo bug: arreglo + test crear-en-nube → reversa → `account` y `subcategory` intactos, con control rojo sin el arreglo.
- Si no hubo bug: guardia de regresión equivalente y ticket bajado a `medium`.
- Review adversarial hecha.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, ticket movido, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Repro de extremo a extremo con nube real en el simulador?** → No: test de integración sobre el camino de la reversa.
Por qué: la reversa espera a que el espejo de CloudKit exporte (`reverseUpload`), y el simulador no tiene cuenta de iCloud; además la sesión de la nube en el simulador necesita `YALA_DEV_SHARED_SECRET`, que es un secreto de Wrangler que no está en `~/Secrets`. Alternativa descartada: pedir un iPhone o el secreto, que deja la sesión parada por algo que el encargo ya prevé.

**D2 · ¿Qué recorre el test?** → Los pasos REALES del `MigrationWorkExecutor` que escriben en el store personal en la ventana de la reversa (drenaje con pull, verificación con pull, barrido de zombies, rebinds, auto-cura de duplicados, muestreo de subida) y el dedup del arranque siguiente, sobre un store on-disk y contra un backend falso que guarda lo subido y devuelve su eco por `server_seq`.
Por qué: el eco de la propia fila es lo único que distingue al movimiento de la época nube de los 2.311 anteriores. Alternativa descartada: un test sobre el runner con ejecutor falso, que no ejecuta ninguna escritura real.

**D3 · Variantes** → (a) reversa inmediata, con el eco llegando dentro de la reversa; (b) reversa tras varios ciclos de la nube; (c) el movimiento creado en otro contexto del mismo contenedor con las inversas ya cargadas en el de la reversa. En las tres se lee también tras «matar y reabrir» (contenedor nuevo sobre el mismo disco).
Por qué: son los sospechosos (a) y (c) del ticket que se pueden ejercer sin CloudKit; el (b) —el remontaje del espejo— queda fuera y se dice.

**D4 · Si no se reproduce** → el test se queda como guardia de regresión, el ticket baja a `medium` con la repro escrita y se mueve a `qa` si hay guion de device-QA útil; sin cambio de código de producto.
Por qué: es lo que pide el encargo (punto 3). Alternativa descartada: «arreglar» un sospechoso no reproducido, que sería cambiar sync sin evidencia.

**D5 · Review adversarial** → Se hace igual sobre el test y su razonamiento (¿el fixture es discriminante?), aunque no haya cambio de producto.
Por qué: un test que no puede fallar es peor que ninguno: diría «intacto» sobre el camino roto. Se demuestra con un mutante que nil-ea la relación en el apply.
