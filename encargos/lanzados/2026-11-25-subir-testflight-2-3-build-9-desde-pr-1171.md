Yala
# Subir a TestFlight la build 9 de 2.3 desde el PR en borrador
---
toca: Yala.xcodeproj/project.pbxproj,docs/qa/testflight-2-3-9/,docs/guias/novedades-2-3/,Cloudkit Schemas/yala-production.ckdb,Cloudkit Schemas/yala_dev-production.ckdb,tickets/backlog/2026-11-24-barrido-y-testflight-2-3-build-9.md,tickets/done/2026-11-24-barrido-y-testflight-2-3-build-9.md,tickets/backlog/2026-11-25-subir-testflight-2-3-build-9-desde-pr-1171.md,tickets/done/2026-11-25-subir-testflight-2-3-build-9-desde-pr-1171.md
esfuerzo: high
cierre: cierra-sola
---

Continuación de la sesión «barrido-y-testflight-2-3-build-9», que cerró con un checkpoint nocturno: el barrido salió bien, pero la build 9 no se subió porque el campo nuevo de la Bandeja `CD_InboxDraft.CD_joinRecordRaw` no existe en el esquema de iCloud (CloudKit) de **Producción**. Si se sube así, en TestFlight la cuenta deja de sincronizar con iCloud sin avisar en cuanto la Bandeja une un borrador.

Decisión de Jürgen (25-nov, 06:16–06:17 Lima): OK a que Dan dé de alta el campo en CloudKit Producción y despliegue g36_01 + Worker v11; después se sube la build 9 desde el PR en borrador. El alta y los despliegues los hace Dan, **no esta sesión**.

## Contexto
- PR en borrador: https://github.com/jur211296/Yala/pull/1171 (rama `encargo/2026-11-25-barrido-y-testflight-2-3-build-9`). Ya trae el número de build 9, las notas de prueba (`docs/qa/testflight-2-3-9/notas-que-probar.txt`), el delta de la guía de novedades (`docs/guias/novedades-2-3/delta_2026_11_25.json`) y la lista del barrido.
- Checkpoint: `~/Claude/flota/checkpoints/01M88X7BZT585RY4JKB1865RP6/` en la Mini (`contexto.md`, `manifiesto.json`). Commit del checkpoint `677e736df7bc`.
- Pasos ya escritos: sección «Para continuar, cuando el campo esté en Producción» de `tickets/backlog/2026-11-24-barrido-y-testflight-2-3-build-9.md` en esa rama.
- Artifact del barrido: https://claude.ai/artifact/PQNZ2sJBmoHrNAdCd6iN7N (iPhone 14 + simulador, 11 pruebas de interfaz en verde, cifras Panel = Flujo de caja = widget, sin bugs graves).

## Qué se pide
1. Trabaja sobre la rama del PR 1171. **El barrido ya está hecho: no lo repitas.** Solo un smoke rápido en el iPhone 14 por DeviceMCP (abrir la app, Bandeja, Panel) y, si al rebasear entró algo nuevo de la app en 2.3, un barrido corto de eso.
2. **GATE, antes de archivar:** verifica que `CD_joinRecordRaw` (tipo `CD_InboxDraft`) existe en el esquema de **Producción** de CloudKit, por ejemplo con `xcrun cktool export-schema --environment production` y la clave de gestión que ya usa el repo. Si todavía no existe: en modo semi, espera con la sesión viva y reintenta cada 10 min, hasta 60 min, avisando el avance; si sigue faltando, deja un checkpoint recuperable y una card «Espera decisión» para Jürgen, y no subas. En modo nocturno, lo mismo, sin asumir respuestas. **Nunca subas sin el campo en Producción.** No despliegues tú el esquema ni el Worker.
3. Con el campo presente: vuelve a exportar `Cloudkit Schemas/yala-production.ckdb` y `yala_dev-production.ckdb` y vacía `pendingProductionDeploy`, como dice «Para continuar» (si ese archivo está fuera del `toca`, tócalo igual y anótalo).
4. `git fetch` y rebase sobre `origin/2.3` (si el pull se frena por cambios locales que no son tuyos ni urgentes, `git stash` y sigue). La build tiene que llevar todo lo mergeado en 2.3 hasta ese momento. Con el CI de 2.3 en verde, archiva `Yala` (Release) y sube la **build 9** a TestFlight como dice «Para continuar»: `scripts/asc-preflight.sh`, subida con `asc` y firma en la nube con la clave `.p8`, sondeo de `asc builds uploads list` hasta `COMPLETE`, dSYM a Sentry (`scripts/sentry-subir-dsym.sh`), notas «Qué probar» y grupo interno. Puedes hacerlo en la Mini o en la Max. No envíes a revisión de App Store. Si fallan credenciales o firmas, no las inventes: `BLOQUEANTE:`.
5. Aplica el delta a la guía de novedades y publícala en su URL.
- iPhone 14 por DeviceMCP para el smoke. Un segundo simulador solo en la Max; en la Mini, uno solo. Pipeline serial: build con `xcodebuild -jobs 2` sin simulador booteado, luego un simulador, y apagarlo al terminar. No uses `-derivedDataPath /tmp/claude-*`. Al arrancar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar.
- Presupuesto de pruebas de interfaz: corre solo las que toca el cambio. Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue. Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo. Ninguna espera de más de 3 min sin escribir avance.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- El esquema de CloudKit de Producción, el gateway, las migraciones y el Worker (eso lo hace Dan). Nada de código de la app salvo un arreglo imprescindible para subir (anotado).

## Cómo entregar
- Saca el PR 1171 de borrador, sin firma de IA en commits ni PR, con auto merge activado, y cierra sin esperar al CI.
- **Entregable visual:** artifact de Claude con el número de build subido, lo que incluye (lo mergeado desde la build 8) y qué probar en el iPhone. Link en «Qué salió».
- En «Qué salió»: el número de build subido, el link de TestFlight o App Store Connect, las notas de prueba tal como quedaron y el link del artifact.
- Cierre según el modo fijado al arrancar: completo → `/cerrar-total`; si falta algo vital, checkpoint sin subir lo incompleto y card «Espera decisión». Siempre con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada». Al cerrar, apaga y borra los simuladores que usaste.
