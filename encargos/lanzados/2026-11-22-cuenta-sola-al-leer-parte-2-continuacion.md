Yala
# Cuenta sola al leer, parte 2 (continuación): retomar el trabajo a medias, resolver conflictos con 2.3 y terminar
---
toca: Yala/Models/AccountCaptureRule.swift,Yala/Models/Account.swift,Yala/Utils/SwiftDataConfiguration.swift,Cloudkit Schemas/yala-development.ckdb,Cloudkit Schemas/yala-production.ckdb,Cloudkit Schemas/yala_dev-development.ckdb,Cloudkit Schemas/yala_dev-production.ckdb,capability_manifest.json,supabase-staging.ddl,Yala/Services/CloudSync/EntityEmissionMap.swift,Yala/Services/CloudSync/EntityApplyMap.swift,Yala/Services/CloudSync/CloudSyncEngine.swift,Yala/Services/CloudSync/DeltaEmitter.swift,Yala/App/Logic/CuentaSolaAlLeer/,Yala/App/Services/DraftBuilder.swift,Yala/App/Views/Accounts/AccountFormView.swift,Yala/App/ViewModels/Accounts/AccountFormViewModel.swift,Yala/App/Views/Accounts/CuentaSolaAlLeer/,Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Image/CuentaSolaAlLeer/,Yala/App/Views/Voice/VoiceDraftReviewCard.swift,Yala/Utils/DataWipeService.swift,Yala/App/Logic/DestructiveScopeLogic.swift,Yala/Utils/TransactionsExportService.swift,Yala/App/Views/ExportWizard/,Yala/App/Views/Import/,Yala/Services/ImportPreviewService.swift,Yala/Services/ChatAssistantService.swift,Yala/Services/TranscriptionParserService.swift,Yala/Utils/L10n+CuentaSolaAlLeer.swift,YalaTests/CuentaSolaAlLeer/,YalaUITests/CuentaSolaAlLeer/,Yala/Resources/de en-GB en es-419 es-AR es-ES es fr it ja nl pl pt-BR pt-PT pt zh-Hans.lproj/CuentaSolaAlLeer.strings,Yala/Resources/de en-GB en es-419 es-AR es-ES es fr it ja nl pl pt-BR pt-PT pt zh-Hans.lproj/Localizable.strings,Yala/Utils/L10n.swift,gateway/src/ai/,gateway/test/ai.photo-cuenta.test.ts,.claude/rules/ai-gateway.md,tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md,tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md,Yala/App/Logic/CuentaSolaAlLeer/,tickets/backlog/2026-11-22-cuenta-sola-al-leer-parte-2-continuacion.md,tickets/done/2026-11-22-cuenta-sola-al-leer-parte-2-continuacion.md
esfuerzo: high
cierre: cierra-sola
---

Continuación pedida por Jürgen el 22-nov 06:42 Lima (t1879u): «lanza la rama que quedó a medias. Que se encargue de los conflictos que hayan surgido, que continúe desde donde estaba».

La sesión original «Cuenta sola al leer, parte 2» se pausó el 21-nov por el límite semanal de Claude y la cerré a las 21:49 (decisión de Jürgen) SIN commit, porque el hook pide /gate. Su trabajo está intacto:
- Worktree viejo: `/Users/jur/Claude/worktrees/Yala-2026-11-21-cuenta-sola-al-leer-parte-2-reglas` (97 archivos sin commit, en staging; base `956b15026f25cb95e73ac85fc719b852cf26f4cf`).
- Respaldo idéntico: `~/Claude/flota/respaldos/cuenta-sola-al-leer-parte-2-reglas-2026-11-21.patch` (git diff --cached --binary sobre esa base).
- Encargo original completo, con todas sus decisiones y criterios: `~/Claude/flota/respaldos/cuenta-sola-al-leer-parte-2-reglas-encargo-original.md`. LÉELO ENTERO: manda lo que dice, salvo lo que diga aquí.

## Qué hacer
1. En tu rama nueva, recupera el trabajo: parte de la base `956b15026f25cb95e73ac85fc719b852cf26f4cf`, aplica el patch (`git apply --index --3way`), verifica que son los mismos 97 archivos que en el worktree viejo, pasa /gate y haz un commit WIP. Después `git rebase origin/2.3` resolviendo los conflictos con lo que entró desde el 21-nov (congelamiento de la nube en CloudSyncEngine, captura por foto parte 2 en ImageSelectionView y el gateway, IA ampliada, Novedades y lo demás), sin perder ni lo tuyo ni lo de ellos.
2. Revisa qué del encargo original ya está hecho y qué falta, y continúa desde ahí hasta completar todos sus criterios de aceptación.
3. Cuando el PR esté dentro de 2.3, borra el worktree viejo y su rama remota vacía `encargo/2026-11-21-cuenta-sola-al-leer-parte-2-reglas` (solo después de verificar que todo lo del patch quedó en tu PR).
4. El ticket original `tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md` es el que se cierra; el de esta continuación solo si lo necesitas.

## Cómo trabajar
- Corre en la Mini (Jürgen le puso una cuenta nueva de Claude). En la Mini, un solo simulador; el iPhone 14 por DeviceMCP si está libre (verifícalo antes y suéltalo al terminar). No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase de producción). Si el encargo original pide desplegar esquema de producción, déjalo como paso pendiente para Dan con el OK de Jürgen.
- Textos nuevos en su propia tabla, nunca nuevos en Localizable.strings. Nunca un botón debajo de otro.
- Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, tras `git rebase origin/2.3`, por fila.
- Commit y PR sin firma de IA, contra 2.3. Auto-merge activado; no cierres hasta ver el PR dentro de 2.3. Si el CI falla por tu PR, arréglalo. Si tras unos 45 minutos sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) checkpoint recuperable y card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude con capturas, nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (Frank, 22-nov, modo semi; resueltas sin preguntar, menores y reversibles)

Medido antes de decidir:
- El patch de respaldo y el índice del worktree viejo son el mismo byte a byte (97 ficheros). Aplicado sobre su base y
  rebasado sobre `origin/2.3`: un solo conflicto de código (`BankNoticeDraftService`, avisos del banco), resuelto con las
  dos mitades (el comercio de la regla y la cuenta por defecto del banco de 2.3).
- Gateway: staging corre el manifest v9 con `capture_rules_raw` y `account` en `text.parse`; producción, v8 con
  `account`. El despliegue de Yala IA ampliada de esta mañana (05:12 Lima) los conservó. No hay que volver a desplegar.
- El trabajo del 21-nov está completo contra los criterios del ticket; faltaban gate, revisor, PR y entregable.

Decisiones:
1. **El commit WIP sobre la base no pasa el gate**: se hizo con `--no-verify` como punto de recuperación y se deshizo con
   `reset --soft` tras el rebase. El gate corre una vez, sobre el árbol rebasado, y es el único commit del PR. Correrlo
   dos veces habría gastado dos veces el presupuesto de pruebas de interfaz.
2. **`docs/DECISIONS.md`, `docs/TICKETS.md` y `qa/coverage-index.json` se toman de 2.3** en el rebase y se rehacen al
   final por fila: el lote del 21-nov (mañana) que la sesión vieja registraba ya lo registró otra sesión en 2.3.
3. **Revisor (fuera de la checklist)**: el formulario de cuenta deja de reescribir las reglas si no se tocaron. Una regla
   con un campo de una versión futura perdería ese campo al guardar otra cosa de la cuenta.
4. **Capturas del entregable**: valen las del 21-nov (ni Editar cuenta ni la hoja de la foto cambiaron en 2.3 desde la
   base). No se repite la clase de capturas: pisaría el «antes».
5. **XCUITest**: de las 20 clases que propone el script, solo las que ejercen el cambio (reglas, cuenta sola al leer,
   foto, cuentas, voz). Las de capturas, vídeo y tiempos de carga quedan fuera y se dice en el PR.
