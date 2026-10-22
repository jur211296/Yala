# Paso 4 rediseño: «Primera vez → privado» en instalación fresca debe validar iCloud antes de reiniciar

## Contexto
Cola autónoma del rediseño de sesiones (Jürgen 2026-09-10). Pasos 0–3 mergeados en `2.1` (último: PR #132 reverse-cutover born-cloud). ESTE es el **paso 4** de `tickets/backlog/session-redesign-implementation-order.md`: `welcome-private-fresh-start-skips-icloud-check` (**[adv]**). Quien arranca EN CONTEXTO LIMPIO: lee ADR «Sesiones — dos ejes» §9, la matriz, el ticket entero (sobre todo «Decisiones de Jürgen»), y re-grepea las líneas citadas (envejecen).

## Que se pide
Arreglar el bug medido en device: instalación fresca + «Es mi primera vez» → «Tu cuenta en tu iCloud privado» no valida iCloud; pide reinicio y al reabrir mete onboarding completo encima de datos viejos que iCloud está bajando. La validación tiene que preguntar a **iCloud**, no al store local neutro. Cumplir los 4 puntos del ADR §9 y los criterios de aceptación del ticket (alert antes de cualquier pantalla de reinicio; borrar con doble confirmación + reinicio limpio; cancelar vuelve al chooser; iCloud vacío → onboarding directo; sin iCloud → aviso + local; kill-safety del borrado). Review adversarial obligatoria (varias lentes + refutación). `/gate` verde antes de commit. Al cerrar: marcar filas de la matriz, actualizar `qa/coverage-index.json`, board + **`docs/TICKETS.md`**. Device-QA CloudKit queda en `tickets/qa/` para Jürgen — no declares PASS desde simulador.

## Que NO hay que tocar
- Rama nube (`.cloudAccount`).
- Qué borra «Vaciar datos» (eso es paso 9 / `session-exits-one-verb-per-session`).
- marketing/ (Lola).
- clinicas-dentales-bi.
- No inventar decisiones de producto nuevas: si aparece una, PARA y avisa.

## Como se sabe que esta bien
Criterios del ticket en verde a nivel lógica/unit; device-QA listado para Jürgen; PR mergeado a `2.1`; board e índice al día; `/cerrar-total` (worktree).

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Nadie estaba delante: cada nodo lo contesté yo con mi recomendación y seguí. Se discute en el PR. El
desarrollo largo, con las coordenadas re-medidas, vive en el ticket
(`tickets/in-progress/welcome-private-fresh-start-skips-icloud-check.md`, sección «Paso 0»).

| # | Decisión | Qué elegí | Por qué |
|---|---|---|---|
| D1 | ¿Alert de `ContentView` o step del container? | **Step**, molde `.groupsGate` | Un `.alert` del anchor DESMONTA el cover del Welcome (medido, `ShellDataAlertsModifier.swift:63-88`) y dos source-scans prohíben `.alert(` en el container. La doble confirmación va como `.confirmationDialog` dentro de la vista del step |
| D2 | ¿Cómo se pregunta a iCloud? | `CKDatabase.recordZoneChanges`, zonas enumeradas con `allRecordZones()` | `CKQueryOperation` exigiría índices `queryable` que `NSPersistentCloudKitContainer` no garantiza; y el literal de la zona no se hardcodea porque hoy no existe en producción |
| D3 | ¿Qué borra «borrar»? | **La zona del mirror en CloudKit**, no `wipeAllUserData` | El cuerpo del ticket y su AC se contradicen: con el store fresco vacío y sin espejo, `wipeAllUserData` no borra nada de iCloud y el AC exige cero registros allí. Manda el AC |
| D4 | Kill-safety del borrado | Arm propio + `armNeutralMount`, desarmar al final | Molde de `performSignOutWipeIfArmed`. Sin el neutro durable, un kill a mitad monta `.iCloudMirror` en el arranque siguiente e importa el corpus que se estaba borrando |
| D5 | No se puede preguntar (red caída) | **Reintentar**, como `WelcomeRestoreView` con `.error` | Seguir a ciegas con el mirror adjunto reproduce el bug en cuanto vuelva la red |
| D6 | El espejo que se adjunta tarde | **Preguntado a Jürgen** (2026-09-10) | Las tres salidas del alert se traducen bien salvo «cancelar», que ahí no tiene chooser al que volver. El resto del ticket no depende de la respuesta |
