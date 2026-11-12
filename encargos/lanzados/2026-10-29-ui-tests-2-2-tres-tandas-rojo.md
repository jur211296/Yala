---
esfuerzo: high
---
# Dejar en verde las tres tandas de UI tests de 2.2 (YalaUITests, tandas 1-3): reproducir en local, separar flake de regresión y arreglar la causa raíz en un solo PR a 2.2

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `ui-tests-2-2-tres-tandas-rojo` · Sesión cola **S27k** · al cerrar → **S27tf** (TestFlight 2.2 (4)).
Card: `tablero ver tablero-las-tres-tandas-de-pruebas-de-interfaz-d-5nfv`.

## Contexto
Pedido de Jürgen (2026-10-29 12:29 Lima), antes de subir TestFlight 2.2 (4). En el run programado `2.2 QA` https://github.com/jur211296/Yala/actions/runs/40899279330 (commit `1f7ee6d`, ya incluye #683-#687) las tres tandas de UI tests fallaron. El run sale verde porque la UI es advisory y corre con `continue-on-error`. `gh run view --log-failed` no trae nada por eso: usa `gh run view -R jur211296/Yala --job <id> --log` (tanda 1 `123536812060`, tanda 2 `123536811930`, tanda 3 `123536811893`).

Lo que se ve en los logs (diagnóstico rápido, verifícalo):
- **Las tres tandas se cortaron por timeout de 110 min** (`has timed out after 110 minutes`), ~2h13m de job. Es la causa principal del rojo: los reintentos de las pruebas que fallan y lotes lentos (de 450-750 s) se comen el presupuesto.
- **Fallan en los 3 intentos (candidatas a regresión o test desfasado):**
  - `BulkEditUITests.test_bulkEditNoteCompletes` (tanda 2), `BulkEditUITests.swift:83`: no existe `bulk_edit_button`. Ojo: ya hay card «Los dos tests de edición masiva (`BulkEditUITests`) fallan en el iPhone SE»; mira si es la misma causa y enlázala.
  - `GroupsLote19DecididoUITests.test_archiveWithOnlyRoundingResidue_noDebtWarning_noticeAndUndo` (tanda 2), `:119-120`: no sale el aviso «Lo moviste a Archivados» ni `group_archived_undo`.
  - `AIConsentAlertUITests.test_voicePillWithoutConsent_showsTheNotice_withoutTheProviderName_andCancelCloses` (tanda 1), `:43` y `XCUIApplication+Yala.swift:370`: «Cancelar» no cierra / `Timed out while evaluating UI query` (130-210 s por intento).
- **Fallan y pasan al reintento (huelen a flake):** `InboxCrudUITests.test_discardingFromEditorMenuOffersUndoThatBringsItBack` (`draft_discard_undo` no hittable; #687 tocó la Bandeja, confírmalo), `AccountLinesUITests.test_savingsForm_offersLines` (avatar de Perfil tapado), `ExternalEntryForeignSheetUITests.test_halfFilledFormInAnotherTab_...`, y en tanda 2 `AccountCardPickersUITests` (dos tests).
- PRs recientes en 2.2: #683 (Yala IA sin categoría), #684 (Vercel encargo/*), #685 (copy «este dispositivo» en 16 idiomas: revisa si algún test busca el texto viejo), #686 (puerta de Grupos era CloudKit), #687 (Bandeja: borrar dos borradores seguidos).

## Qué se pide
1. Reproduce en local cada test que falla, con el pipeline serial de la Mini.
2. Clasifica cada uno: regresión de un PR (dilo con número), test desfasado por copy o UI, o flake. Para los flakes, arregla la causa (esperas, hittability, sheets sin cerrar, siembra), no subas reintentos.
3. Arregla la causa raíz de cada falla. **No se vale saltar tests ni marcarlos como skip** sin justificarlo en un ticket (`tickets/backlog/…` + card) enlazado desde el PR.
4. Ataca también el timeout de 110 min: mide cuánto suma cada tanda y explica por qué ya no cabe. Si hay que rebalancear tandas o subir el límite, justifícalo en el PR con cifras.
5. Todo en **un solo PR a 2.2**. Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

## Qué NO hay que tocar
- No quites `continue-on-error` ni cambies el carácter advisory de la UI en esta sesión.
- No toques el comportamiento de producto salvo que la falla sea una regresión real; en ese caso, arregla el código y dilo.
- Nada de `marketing/`.

## Build y simulador
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Un solo simulador. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. Al cerrar, apaga y borra los sims que usaste y corre `limpiar-mac --apply`.

## Cómo se sabe que está bien
- Las tres tandas de YalaUITests en verde en el CI del PR (sin timeout y sin fallos tras reintento).
- Cada test que fallaba tiene su diagnóstico (regresión / copy / flake) y su arreglo en el cuerpo del PR.
- Cero skips nuevos sin ticket.
- Card `5nfv` cerrada al mergear.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: el corte de 110 min pasa en las tres tandas **cada noche desde al menos el 23-oct**; la suite tiene 646 casos en 159 suites (250 el 9-oct) y en el runner cada caso cuesta 46 s de media; los reintentos de los rojos suman ~16 min de los ~330 de UI de la noche del 29.

**D1 · ¿Más tandas o subir el tope?** → 8 tandas con `max-parallel: 3`; el tope de 110/150 se queda.
Por qué: simulado con los tiempos por suite de la nocturna 40899279330, la tanda más larga queda en 66 min (1,7x de su tope); `max-parallel: 3` mantiene el `macOS` libre que hoy tiene el CI de los PR. Alternativa descartada: 4-5 tandas subiendo el tope (126-106 min por tanda, sin holgura y con la suite creciendo), y abrir las 8 a la vez (cola igual por el límite de `macOS` y por delante de los PR).

**D2 · El primer test de cada tanda cae (AIConsentAlert, AccountCardPickers) esperando `uitest_ready`** → paso nuevo «Calentar el simulador» (arranca, instala, abre Yala 60 s) antes de la UI, advisory.
Por qué: es la regla medida de `testing.md` (la primera corrida tras arrancar un simulador de iOS 27 falla) y el patrón de la historia: siempre el primer caso de la tanda. Alternativa descartada: subir esperas en esos dos tests (taparía la causa y la pagaría el siguiente primero).

**D3 · Tests que leen el aviso de 5 s con «Deshacer» tras otra espera** → `-uitest-undo-notice-seconds 30` en cada test que lo necesita (6), no como default global de `launchForUITest`.
Por qué: es el molde ya decidido en `testing.md` (`UXAudit22Lote08UITests`); un default global alargaría también los borrados diferidos en tests que miden que se cumplan. Alternativa descartada: subir los `waitForExistence`.

**D4 · `BulkEditUITests.test_bulkEditNoteCompletes`** → se reproduce en local antes de decidir; si es el test (espera ausente, reparto de filas), se arregla el test; si es producto, se arregla y se dice con su PR.

**D5 · ¿Cómo se ve «verde en el CI del PR» si la UI no corre en un PR?** → `workflow_dispatch` de `qa.yml` sobre la rama del encargo, que corre exactamente la nocturna.

**D6 · Flakes de noches anteriores que no salen en la del 29** → solo se tocan si comparten patrón con los de la lista (D3) o si salen en el dispatch de verificación. Lo demás, a «Encontrado».

**D7 · ¿ADR?** → no. Las cifras y el porqué viven en el comentario de `qa.yml` y en `ci-qa.md`; son de mantenimiento del CI, se reemplazan al re-medir.
