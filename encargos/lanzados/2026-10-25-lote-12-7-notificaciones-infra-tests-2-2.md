# Cola 2.2 · lote 12.7 Notificaciones, infraestructura y tests (13 cards)

release: si

## Contexto
Jürgen (24-oct): seguir la cola 2.2 por lotes 12.x; el barrido estricto cierra 2.2. Ya cerraron 12.1–12.6 (PR #632 en cola), Duo, Fundido y assets X. Esta es **12.7 · Notificaciones, infraestructura y tests** — cierre de la serie 12.x 2.2. Base: `origin/2.2`, PR contra 2.2.

Trece cards en «in progress», versión 2.2 (todas cierra sola). Léelas con `tablero ver <id>`:

1. `tablero-bug-el-aviso-de-error-de-storekit-no-se-y5zz` — Bug · El aviso de error de StoreKit no se vacía en el paywall ni en la oferta
2. `tablero-cruzar-tickets-abiertos-con-el-tablero-y-oayf` — Cruzar tickets abiertos con el tablero y deduplicar cards
3. `tablero-el-aviso-de-saldo-de-una-cuenta-no-lleva-bmbp` — El aviso de saldo de una cuenta no lleva a ningún sitio al tocarlo
4. `tablero-el-aviso-de-una-notificacion-puede-perde-1boe` — El aviso de una notificación puede perderse con la app cerrada
5. `tablero-el-golden-20-del-gateway-la-cuenta-conge-si8z` — El golden 20 del gateway (la cuenta congelada sigue pudiendo leer) cae por timeout y nadie comprueba ese invariante
6. `tablero-hay-11-canarios-y-8-rastros-que-nadie-em-yf9t` — Hay 11 canarios y 8 rastros que nadie emite, el índice de cobertura los cita como red, y el gate Pro de Siri no deja señal
7. `tablero-la-politica-solo-nombra-a-openai-actuali-buer` — La política solo nombra a OpenAI: actualizarla antes de encender Gemini u otro proveedor
8. `tablero-los-xcuitest-no-pueden-fingir-que-contes-er5c` — Los XCUITest no pueden fingir qué contesta el servidor sobre una cuenta, y el bloque de identidad del Welcome queda sin cobertura de UI
9. `tablero-maintab-publica-su-hoja-despues-de-que-c-pvwt` — MainTab publica su hoja después de que ContentView drene
10. `tablero-observaciones-manda-a-la-ia-la-nota-libr-ve42` — Observaciones manda a la IA la nota libre del gasto más alto
11. `tablero-release-dev-habla-con-el-gateway-de-prod-xel3` — Release-Dev habla con el gateway de producción con el bundle .dev y no obtiene sesión (¿debe ir a staging?)
12. `tablero-si-los-avisos-de-grupos-dejan-de-llegar-9f9u` — Si los avisos de Grupos dejan de llegar, el servidor no deja rastro y nadie se entera
13. `tablero-tocar-una-notificacion-de-grupo-no-abre-x6p9` — Tocar una notificación de grupo no abre el grupo, y cualquier push dispara una sincronización completa

**No** incluir: segmento de gráfica (sesión propia), FAB / botón «nuevo», barrido, marketing, ni las dos cards nuevas de 12.6 (onda de voz y hoja cuenta eliminada).

Antes de diseñar UI (avisos, deep link de notificación, paywall), mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas).

## Qué se pide
1. Confirma que las trece están en «in progress» con `--agente frank` (ya movidas al lanzar; si alguna quedó fuera, muévela).
2. Arregla cada una según su «hecha cuando». Preferible tests (unit / XCUITest / golden) que fijen la regresión (StoreKit dismiss, deep link de push, canarios/breadcrumbs, seam de cuenta en XCUITest, MainTab sheet). Criterio estricto: solo «in qa» a jurgen (con guion corto) lo grave que el simulador no valida; lo demás a done.
3. Card 2 (cruzar tickets / deduplicar): trabajo de tablero+tickets, no de UI. Cruza abiertos, deduplica cards, cierra o fusiona según la regla de Jürgen (todo ticket con card 1:1 o una card que cubra varios). Sin inventar scope de producto.
4. Card 11 (Release-Dev → staging?): si la card o el código ya fijan staging vs prod, impleméntalo; si falta decisión de destino, deja nota clara, card en «espera decisión» a jurgen, y sigue.
5. Dudas reversibles: opción recomendada + nota en la card. Solo lo irreversible → espera decisión.
6. Tickets nuevos de lo que encuentres, con su card.
7. Capturas antes/después en `capturas/` si hay cambio visible.
8. Al terminar: `/cerrar-total`.

## Dependencias
Arranca ya sobre `origin/2.2` (no esperes CI ni merge del PR anterior). Justo antes de abrir el PR: `git fetch` + un solo rebase sobre `origin/2.2`, y build/simulador una vez después. Solo si dos sesiones tocaran el mismo archivo o una necesitara el código de la otra esperarías el merge; aquí no aplica. Un fallo de CI entra como sesión después, nunca encima.

## Qué NO hay que tocar
- marketing/ y Web/ (Lola).
- Segmento de gráfica / modelo de filtros (sesión aparte).
- FAB / consistencia botón «nuevo».
- Barrido de QA 2.2 (sesión final).
- Onda de voz (propuesta visual) y hoja de cuenta eliminada (después o en su momento).
- Despliegues CloudKit/Supabase de producción.
- No desactivar tests ni saltarse protecciones de rama.

## Cómo se sabe que está bien
Las trece cumplen «hecha cuando» o quedan en in qa/espera con motivo; suite unit en verde; PR a 2.2 en auto-merge; `/cerrar-total`.

## Gate después del CI del PR anterior
Arranca ya sobre `origin/2.2`. Justo antes del gate, si #632 (u otro) sigue en CI, espera a que entre y rebasea una sola vez con el simulador apagado. Si 2.2 no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador después de ese rebase, una sola vez.

## Mini
Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados (sin preguntar); (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 solo simulador iPhone; (4) tests; (5) apagar y borrar ese sim y DerivedData de esta sesión. Prohibido solapar build, sim y UITests. Disco ~26 GB libres (<32 APRETADO): limpia sin preguntar antes del build (`limpiar-mac --apply` si hace falta).

## Ritmo
Después: segmento A (gráfica) → FAB → barrido. Ve directo; no alargues fuera de estas trece.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Worktree → rama `encargo/…` y PR a `2.2` en cola de auto-merge. Las trece cards ya estaban en «in progress» con `frank`.

| # | Card | Decisión | Por qué |
|---|---|---|---|
| 1 | y5zz StoreKit | `clearStoreAlert()` en `SubscriptionView` y `ProTrialOfferSheet`, molde de `UpgradePromptSheet`; source-scan sobre todo `Yala/` | Es lo que pide el ticket; el scan coge una cuarta vista sola |
| 2 | oayf cruzar tickets | Script que cruza tickets abiertos con las cards por slug y enlace; cierra tickets con card en done, enlaza los que tengan card, agrupa los huérfanos en cards por área y deduplica cards con el mismo ticket | Regla de Jürgen (15-oct): todo ticket con card, 1:1 o una que cubra varios. Sin scope de producto nuevo |
| 3 | bmbp aviso de saldo | Done sin código: ya resuelto (L10-14 B, `AlertDeepLink`, tests `UXAudit22Lote10AlertRoutingTests` + XCUITest) | Medido en el árbol |
| 4 | 1boe delegado | Done sin código: `installAsCenterDelegate()` en `didFinishLaunching`, `NotificationColdLaunchTapTests`, barrido 15-oct en simulador | Medido en el árbol |
| 5 | si8z golden 20 | Medir con `console.time` por GET contra staging (credenciales en `~/Secrets`); timeout propio del `it` con la cifra medida ×2; si un GET es el lento, ticket aparte | El ticket ya probó que tarda, no cuelga (9,3 s verde) |
| 6 | yf9t canarios | A: borrar los 8 canarios de Grupos-CloudKit y añadir aviso a los 4 `groupsCk*` (molde de sus vecinos C-3), limpiar citas de `coverage-index.json`. B: `inviteReEmittedFromStore`/`invitePendingExpired` → borrar con sus wrappers (el canal backend no tiene almacén pendiente que re-emitir); `cloudkitBudgetCSVMirrorRebuilt` → medir el backfill y decidir. C (Siri): ya hecho el 21-oct | Reversible; el ticket deja elegir a quien lo haga |
| 7 | buer política IA | Test en `gateway/test/` que lee `Web/src/i18n/translations.ts` (solo lectura, Web es de Lola) y exige que cada proveedor activo en `ROUTES`/`LEGACY_OVERRIDES` aparezca en `privacyProvidersText` de todos los idiomas; nota en el docblock de `PREPARED_ROUTES` y en `ai-gateway.md` | «Hecha cuando»: guarda + documentado |
| 8 | er5c seam `exists` | Launch arg `-uitest-fake-account-kind <nueva|completa|solo-grupos|sin-red>` bajo `#if DEBUG` + `UITestHooks.isActive`, que respeta `CloudAccountClient`; XCUITest de las celdas que alcance sin SIWA real | El ticket lo define; nunca camino de producción |
| 9 | pvwt MainTab | Medir antes de tocar (el ticket lo pide). Si el hueco existe, publicar el bloqueo antes de abrir la hoja; si no, descartar con evidencia | «Inferido, no medido» |
| 10 | ve42 nota a la IA | Mandar la subcategoría (o nada) en vez de la nota libre — recomendada del ticket; coincide con lo que promete el permiso. Sin banco de pago: el campo es una etiqueta y el resto del payload no cambia | Privacidad: alinea con el texto aceptado |
| 11 | xel3 Release-Dev | `DEV_BUILD` en Release-Dev: bundle `.dev`, attest `development` y App Group `.dev` solo los acepta staging; producción le da 401 siempre | Reversible; producción no es un destino que funcione |
| 12 | 9f9u telemetría gateway | `writeDataPoint` en los canarios del gateway (push fallido, token podado, secret ausente, coherencia parcial) con un helper común; `authorization_status` va a ticket aparte (pide DDL de Supabase) | No se despliega producción desde aquí |
| 13 | x6p9 push de grupo | Gateway: `deepLink: "groups/<uuid>"` (pelando `SplitGroup-`) en el fan-out y constante de kinds; cliente: `switch` por `kind`, solo `groups-sync` dispara sync | Ticket |

Gateway: los cambios entran por PR; **no se despliega producción** (lo hace Jürgen con la release). Staging solo si hace falta medir.
Capturas: solo si hay cambio visible (ninguna de estas cards cambia una pantalla a simple vista; el aviso de StoreKit no se reproduce sin StoreKit fallando).
Pase de estrés: la release no cambia UI; se dice en el PR.
