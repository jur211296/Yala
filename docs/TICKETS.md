# Tickets

Index of `tickets/`. Folder name **is** `status`. Filename **is** `id` + `.md` (English kebab-case). Ids assigned by Claude since 2026-08-29.

## Schema

```yaml
---
id: <slug>                          # = filename without .md
status: backlog|in-progress|qa|done|blocked|discarded
priority: high|medium|low           # only if the source had it
area: (if present on the source)
created: (if present on the source)
updated: 2026-08-26
source: YalaWiki/<origin path>
---
# Title
<original body>
```

Rules:

- `status` equals the parent folder. Moving the file and editing `status` is the same act.
- Omit `priority` when the source did not have a real value (`high` / `medium` / `low`). Do not invent it.
- Closed write-ups (bugs `closed`/`fixed`, backlog `done`/`cancelled`) are **not** copied.
- Last line of a migrated body: `migrated from YalaWiki <path> @ 1934e8ad`.
- Do not invent PASS or close a ticket.

Source repo for absorption: `jur211296/YalaWiki` @ `1934e8ad`. This environment could not read that repo (GitHub App sees only `jur211296/Yala`). Bodies are **not** invented. Paths below are the owner map.

## Index (93)

| id | status | path |
|----|--------|------|
| account-goldens-freeze-read-test-times-out | backlog | tickets/backlog/account-goldens-freeze-read-test-times-out.md |
| ai-recommended-budgets | backlog | tickets/backlog/ai-recommended-budgets.md |
| apple-watch | backlog | tickets/backlog/apple-watch.md |
| applepay-shortcut-warm-launch-empty-data | qa | tickets/qa/applepay-shortcut-warm-launch-empty-data.md |
| apppreferences-rewritten-on-launch | blocked | tickets/blocked/apppreferences-rewritten-on-launch.md |
| appstorage-onboarding-desarma-el-aislamiento-de-tests | backlog | tickets/backlog/appstorage-onboarding-desarma-el-aislamiento-de-tests.md |
| aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app | qa | tickets/qa/aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app.md |
| budget-tied-to-income-or-expense | backlog | tickets/backlog/budget-tied-to-income-or-expense.md |
| canarios-y-breadcrumbs-sin-emisor | backlog | tickets/backlog/canarios-y-breadcrumbs-sin-emisor.md |
| cashflow-spend-prediction | backlog | tickets/backlog/cashflow-spend-prediction.md |
| ci-suite-simulador-duplicada-y-allowlist-incompleta | done | tickets/done/ci-suite-simulador-duplicada-y-allowlist-incompleta.md |
| ci-verde-con-la-suite-en-rojo | in-progress | tickets/in-progress/ci-verde-con-la-suite-en-rojo.md |
| cloud-fx-rates-blob-two-faces | qa | tickets/qa/cloud-fx-rates-blob-two-faces.md |
| cloud-tx-epoch-orphan-relations | backlog | tickets/backlog/cloud-tx-epoch-orphan-relations.md |
| creategroup-throw-after-commit-loses-owner | backlog | tickets/backlog/creategroup-throw-after-commit-loses-owner.md |
| debounce-sync-imported-transactions | backlog | tickets/backlog/debounce-sync-imported-transactions.md |
| debt-tracking | backlog | tickets/backlog/debt-tracking.md |
| device-handover-groups-leak | discarded | tickets/discarded/device-handover-groups-leak.md |
| distribution-balance-kpi-skips-fx | backlog | tickets/backlog/distribution-balance-kpi-skips-fx.md |
| doble-conteo-dia1-previo-thismonth | done | tickets/done/doble-conteo-dia1-previo-thismonth.md |
| exportable-insights | backlog | tickets/backlog/exportable-insights.md |
| fx-partial-rate-rows-silent-1to1 | backlog | tickets/backlog/fx-partial-rate-rows-silent-1to1.md |
| fx-pnl-education-card | backlog | tickets/backlog/fx-pnl-education-card.md |
| gate-doc-says-swift-testing-only | backlog | tickets/backlog/gate-doc-says-swift-testing-only.md |
| gateway-has-no-telemetry | backlog | tickets/backlog/gateway-has-no-telemetry.md |
| group-notif-credits-payer-not-editor | done | tickets/done/group-notif-credits-payer-not-editor.md |
| groups-approval-banner-stays | done | tickets/done/groups-approval-banner-stays.md |
| groups-background-emitter-no-upload | done | tickets/done/groups-background-emitter-no-upload.md |
| groups-budget | backlog | tickets/backlog/groups-budget.md |
| groups-cloud-identity-loss-on-migrate | discarded | tickets/discarded/groups-cloud-identity-loss-on-migrate.md |
| groups-cloud-mode-hardening-v1 | discarded | tickets/discarded/groups-cloud-mode-hardening-v1.md |
| groups-consent-door-spec | qa | tickets/qa/groups-consent-door-spec.md |
| groups-deleted-group-detail-stays-open | backlog | tickets/backlog/groups-deleted-group-detail-stays-open.md |
| groups-equal-split-shows-not-participating-on-peer | backlog | tickets/backlog/groups-equal-split-shows-not-participating-on-peer.md |
| groups-expense-notif-only-on-foreground | qa | tickets/qa/groups-expense-notif-only-on-foreground.md |
| groups-ghost-tx-on-delete | done | tickets/done/groups-ghost-tx-on-delete.md |
| groups-guest-currency-from-region | backlog | tickets/backlog/groups-guest-currency-from-region.md |
| groups-import-splitwise-tricount | backlog | tickets/backlog/groups-import-splitwise-tricount.md |
| groups-in-group-search | backlog | tickets/backlog/groups-in-group-search.md |
| groups-invite-skips-unirme-sheet-if-onboarded | backlog | tickets/backlog/groups-invite-skips-unirme-sheet-if-onboarded.md |
| groups-join-intent-reconciler | blocked | tickets/blocked/groups-join-intent-reconciler.md |
| groups-leave-rpc-error-10 | backlog | tickets/backlog/groups-leave-rpc-error-10.md |
| groups-log-expense-via-chat-voice | backlog | tickets/backlog/groups-log-expense-via-chat-voice.md |
| groups-pending-member-can-open-group | backlog | tickets/backlog/groups-pending-member-can-open-group.md |
| groups-reconnect-prune-or-rewire | backlog | tickets/backlog/groups-reconnect-prune-or-rewire.md |
| groups-settlement-reminder | backlog | tickets/backlog/groups-settlement-reminder.md |
| groups-shareable-summary | backlog | tickets/backlog/groups-shareable-summary.md |
| groups-tab-missing-panel-perf | backlog | tickets/backlog/groups-tab-missing-panel-perf.md |
| guest-decline-has-no-screen | in-progress | tickets/in-progress/guest-decline-has-no-screen.md |
| guest-journey-dead-screens | in-progress | tickets/in-progress/guest-journey-dead-screens.md |
| history-token-guard-echo-blind-spot | backlog | tickets/backlog/history-token-guard-echo-blind-spot.md |
| inbox-convert-draft-to-group-expense | done | tickets/done/inbox-convert-draft-to-group-expense.md |
| inbox-crash-convert-to-group-expense | done | tickets/done/inbox-crash-convert-to-group-expense.md |
| insights-precomputed-icon-lookup | backlog | tickets/backlog/insights-precomputed-icon-lookup.md |
| invite-backend-stale-config | qa | tickets/qa/invite-backend-stale-config.md |
| invite-link-five-causes-one-message | in-progress | tickets/in-progress/invite-link-five-causes-one-message.md |
| invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo | backlog | tickets/backlog/invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo.md |
| notifications-not-delivered-testflight | done | tickets/done/notifications-not-delivered-testflight.md |
| only-testing-filters-may-be-silently-empty | backlog | tickets/backlog/only-testing-filters-may-be-silently-empty.md |
| orphan-alerts-behind-fullscreen-covers | backlog | tickets/backlog/orphan-alerts-behind-fullscreen-covers.md |
| panel-accounts-redesign | backlog | tickets/backlog/panel-accounts-redesign.md |
| prefs-domain-per-secondary-session | qa | tickets/qa/prefs-domain-per-secondary-session.md |
| prefs-synced-keys-upload-not-download | qa | tickets/qa/prefs-synced-keys-upload-not-download.md |
| push-client-ignores-yala-kind | backlog | tickets/backlog/push-client-ignores-yala-kind.md |
| records-standalone-amount-discrepancy | backlog | tickets/backlog/records-standalone-amount-discrepancy.md |
| reentry-counts-as-fresh-install | in-progress | tickets/in-progress/reentry-counts-as-fresh-install.md |
| registros-calendario-cuenta-gastos-por-signo | qa | tickets/qa/registros-calendario-cuenta-gastos-por-signo.md |
| rescue-discarded-groups-pull | discarded | tickets/discarded/rescue-discarded-groups-pull.md |
| rojo-heroBuckets-thisWeek-trailing-window | done | tickets/done/rojo-heroBuckets-thisWeek-trailing-window.md |
| savings-tracking | backlog | tickets/backlog/savings-tracking.md |
| scheduled-payment-once-labeled-monthly | backlog | tickets/backlog/scheduled-payment-once-labeled-monthly.md |
| scheduled-payments-notif-dedup | qa | tickets/qa/scheduled-payments-notif-dedup.md |
| secondary-groups-off-wipes-owner | qa | tickets/qa/secondary-groups-off-wipes-owner.md |
| secondary-guest-exit-lock-and-outbox | in-progress | tickets/in-progress/secondary-guest-exit-lock-and-outbox.md |
| secondary-visitor-writes-owner-domain | in-progress | tickets/in-progress/secondary-visitor-writes-owner-domain.md |
| siri-intent-dual-container | qa | tickets/qa/siri-intent-dual-container.md |
| smart-ai-notifications | backlog | tickets/backlog/smart-ai-notifications.md |
| staging-test-credentials-in-public-repo | done | tickets/done/staging-test-credentials-in-public-repo.md |
| staging-test-user-c-does-not-exist | backlog | tickets/backlog/staging-test-user-c-does-not-exist.md |
| storekit-appgroup-siri-pro-gate | qa | tickets/qa/storekit-appgroup-siri-pro-gate.md |
| subscription-success-without-pro | done | tickets/done/subscription-success-without-pro.md |
| synced-prefs-outside-prefsynckey | discarded | tickets/discarded/synced-prefs-outside-prefsynckey.md |
| trends-comparison-kpi-vs-curve | done | tickets/done/trends-comparison-kpi-vs-curve.md |
| trends-insight-card-v2-bullets | backlog | tickets/backlog/trends-insight-card-v2-bullets.md |
| undercount-dias-intervalos-cerrados | backlog | tickets/backlog/undercount-dias-intervalos-cerrados.md |
| update-banner-appstore-criteria | qa | tickets/qa/update-banner-appstore-criteria.md |
| verify-dual-channel-zone-in-supabase | backlog | tickets/backlog/verify-dual-channel-zone-in-supabase.md |
| welcome-copy-blames-owner | qa | tickets/qa/welcome-copy-blames-owner.md |
| welcome-fresh-start-alert-leaves-blank-screen | qa | tickets/qa/welcome-fresh-start-alert-leaves-blank-screen.md |
| welcome-start-fresh-wipes-before-ask | qa | tickets/qa/welcome-start-fresh-wipes-before-ask.md |
| widget-snapshot-visitor-overwrites-owner | qa | tickets/qa/widget-snapshot-visitor-overwrites-owner.md |
| yala-android | backlog | tickets/backlog/yala-android.md |
| zone-decisions-still-per-row | backlog | tickets/backlog/zone-decisions-still-per-row.md |

Counts by folder: backlog 48 · in-progress 7 · qa 18 · blocked 2 · done 13 · discarded 5 = 93.

Frank 2026-09-02 (altas): dos hallazgos del QA de hoy entran en `backlog/`, para que no se pierdan
al cerrar la sesion.

- **`welcome-fresh-start-alert-leaves-blank-screen`** (**high**) — cerrar el alert de «Empezar desde
  cero» por CUALQUIERA de sus dos botones deja el Welcome sin un solo control: hay que matar la app.
  Preexistente y **alcanzable en produccion** (onboarding de quien reinstala teniendo datos). Medido
  con tres lanzamientos y control negativo: pasa con y sin el seam `-uitest-fail-wipe`, y en la rama
  «Cancelar», que no invoca ningun wipe ⇒ no es un fallo del borrado, es el alert. Contradice el
  comentario del propio codigo en `ShellDataAlertsModifier.swift:105` («user queda en el Chooser»).
- **`scheduled-payment-once-labeled-monthly`** (low) — un pago «una sola vez» se rotula «Mensual»:
  `recurrenceBadge` pinta `recurrenceType` y nunca mira `isRecurring`, y `RecurrenceType` no tiene
  caso `once`. Presentacion, no calculo.

Counts recontados sobre disco: backlog 39 → 41, total 76 → 78.

Frank 2026-09-02 (QA): `inbox-convert-draft-to-group-expense` **PASA y se cierra a `done/`** — los 12
ACs verificados EN PANTALLA (sim iPhone 17 Pro), incluida la FECHA, que era el punto ciego y que hasta
hoy solo estaba «medida en el código». Lo desbloqueó el seam `DevSeedDrafts.draftBDaysInThePast`
(`3ba69eab`): antes los dos borradores del fixture nacían en `.now`, así que un falso verde era
indistinguible de uno real. Con esto caen los cuatro puntos que la entrada del 2026-08-14 (más abajo)
dejaba pendientes: guardar, cancelar, los dos negativos y la fecha. **Aviso para quien lo repita:**
tras guardar, el Inbox vuelve a mostrar un pendiente con el mismo nombre y el contador vuelve a 2 —
NO es el draft sin borrar, es la contraparte del bridge; está documentado en el ticket.
Fuera de esta cola: el negativo de INGRESO no es alcanzable desde la UI (el seed no siembra drafts de
ingreso) y el sync real al grupo es cross-device.

**Counts RECONTADOS sobre disco, y corrigen un desfase que venía de antes:** el índice decía
`backlog 34 · qa 15 · done 8 = 69` y el disco tiene `backlog 39 · qa 14 · done 11 = 76`. Mi
movimiento solo explica `qa 15 → 14` y `done 10 → 11`; los otros 7 eran drift acumulado sin
registrar.

Jurgen 2026-08-28 (alta): `groups-invite-skips-unirme-sheet-if-onboarded` entra en `backlog/` con
prioridad **high** — reporte de device del owner (Lima, TF 2.1 build 12): B, con la cuenta **ya creada**,
abrió un enlace de invitación y **no vio la hoja de «Unirme»**; el alta se hizo sola. El owner pide que
esa hoja aparezca **siempre**, venga de primer plano, de segundo plano o estando ya dentro de la app. Sin
implementación: cero Swift. **Medido** en `2.1` @ `2175e53e`, y escrito en el ticket como medición y no
como causa única de esa corrida (no hubo captura de Console): con `hasCompletedOnboarding` el camino del
invite puede devolver `.join` y saltarse `.presentInviteOnboarding` — el corte vive en
`GroupsGateLogic.nextStep:121`, que es lo que `GroupBackendInviteEntryLogic.nextStep` consume, y se repite
en el drain de `ContentView:960`. Lo que hay hoy **cumple su propio contrato** (ese paso existe para el
usuario FRESCO), así que lo que el owner pide es un cambio de contrato con dos tests que habrá que
actualizar a propósito. **No** se dobla con `groups-join-intent-reconciler` (member que no nacía / «¡Todo
listo!» falso), ni con `groups-pending-member-can-open-group` (ya en el árbol vía PR 46), ni con
`invite-link-five-causes-one-message` (copy de enlace inválido). Counts tras el alta en este árbol:
backlog 33 → 34, total 68 → 69.

Jurgen 2026-08-28 (alta): `groups-expense-notif-only-on-foreground` entra en `backlog/` con prioridad
**high** — reporte de device del owner en TF **2.1 build 12**: A crea/edita un gasto de grupo y la
notificación llega a B **solo al abrir la app**, nada mientras B está fuera; a A no le llega (era el
actor). Sin causa declarada y sin implementación: el ticket lleva el mapa **medido** del camino
(la notif de grupo es LOCAL y nace tras el pull —
`GroupsSyncClient.applyPulledPage:1937` → `GroupNotificationService.processRemoteChanges`) y las
hipótesis con su señal discriminante. **No** se declara el silent push roto: no está medido.
`group-notif-credits-payer-not-editor` ya está `done/` (PR 47, PASS de atribución/eco); este alta **no**
lo reabre. Counts tras el alta en este árbol: backlog 32 → 33, total 67 → 68.

Jurgen 2026-08-28 (alta): `groups-equal-split-shows-not-participating-on-peer` entra en `backlog/`
con prioridad **high** — device-QA del owner en TF 2.1 build 12, dos teléfonos, grupo ya en uso ese
día: el gasto que A reparte mitad y mitad se ve en B como si B no hubiera participado, y solo se
actualiza tras force-quit + reentrada en B. Es **un** ticket con dos tiempos (primera apertura
equivocada / tras force-quit actualizado), **sin causa raíz declarada** y **sin** convertirlo en el
bug de notificaciones (B no recibió aviso; el owner lo deja fuera a propósito). Mismo día se añaden
**dos observaciones de contraste** al mismo ticket: un gasto posterior creado en A convirtiendo un
borrador del Inbox, y una edición del importe de un gasto ya existente — las dos llegaron bien a B
**sin** matar la app (PASS del owner **de ese gasto** y **de esa edición**, no del ticket). Una de tres
observaciones falló: el defecto queda como **condicional, no constante** (no es una medida de
frecuencia), y el ticket **no** se cierra: qué distingue el caso que falla de los que no sigue sin
resolver. Sin implementación: cero Swift. Counts tras el alta en este árbol: backlog 31 → 32, total
66 → 67. Sin tocar `qa/coverage-index.json` (no hay código nuevo bajo `Yala/`).

Jurgen 2026-08-28 (alta, la segunda del día): `groups-leave-rpc-error-10` entra en `backlog/` con
prioridad **high** — hallazgo de device en Lima (TF `2.1` build 12, dos teléfonos): en uno «Salir del
grupo» funciona y en el otro falla con el alert crudo «Error de Yala.GroupsRPCError 10», y en esa
pantalla no hay botón de borrar el grupo. Es **un** ticket con dos caras (el número crudo del canal y
el agujero de UX de último dueño / `isOwner` local que solo escribe el creador) porque comparten
setup, pantalla y callejón sin salida. Sin implementación: cero Swift, `qa/coverage-index.json`
intacto. **Nada se declara como causa**: el mapeo del discriminante 10 → `channelDisabled` está
medido en el árbol `2.1` @ `2175e53e` (orden de declaración del enum), y el ticket deja escrito qué
parte de esa lectura es inferencia y cómo zanjarla. Counts tras el alta en este árbol: backlog 30 → 31,
total 65 → 66.

Jurgen 2026-08-28 (cierre): `inbox-crash-convert-to-group-expense` pasa a `done/` por **QA device PASS**
del owner — TF 2.1 build 12, teléfono A: convertir un borrador de la Bandeja en gasto compartido de un
grupo en uso **no crasheó**, el borrador salió de la bandeja y el gasto quedó en el grupo. El fix ya
estaba en `2.1` (`88a43237`, medido hoy como ancestro), así que **este cierre es QA, no un fix nuevo**, y
hoy no hubo subida a TestFlight. El PASS cubre el path de **conversión**, no los 4 sheets de finalización
de grupo a los que el fix se amplió (esos los sostiene `InboxRowPruneCoordinatorTests`, determinista). El
hermano de feature `inbox-convert-draft-to-group-expense` **se evaluó y se queda en `qa/`**: su guion
pendiente tiene cuatro puntos y hoy solo se tocó uno (cancelar, los dos casos negativos y la fecha en
pantalla siguen sin ejercitar) ⇒ AC distinta, no se cierra por inferencia; queda anotado en el ticket.
Counts RECONTADOS sobre disco tras el movimiento: qa 16 → 15, done 7 → 8; el total sigue en 65 porque es
un movimiento, no un ticket nuevo.

Jurgen 2026-08-28 (cierre): `group-notif-credits-payer-not-editor` pasa a `done/` con **PASS del owner**
(Lima). Dos teléfonos, el mismo grupo que el resto del QA de hoy, **TF 2.1 build 12**: **A** fue quien actuó
(crear/editar) y **A no recibió notificación** —ningún eco que atribuyera su cambio a **B**—, mientras **B sí
la recibió**. **Lo que el PASS no cubre, escrito en el ticket:** la notificación de B llegó **solo al abrir la
app**, que es *cuándo* se entrega y no *a quién* se atribuye ⇒ va en ticket aparte
(`groups-expense-notif-only-on-foreground`, en alta separada) y **no se dobla aquí** ni como PASS ni como
FAIL; el escenario original (gasto pagado por Pia, editado por el owner) **no consta re-corrido palabra por
palabra** —el reporte no fija quién pagaba, y con pagador = A el silencio ya existía antes del fix, así que
esa variante no discrimina—; el **texto** de la notificación de B no está medido; y liquidaciones, gasto
nuevo, terceros y 2º device siguen sin correr. Cierre de **QA**, no fix nuevo: sin cambio de código, sin
subida a TestFlight, A7/M5 en HOLD. Counts medidos tras el movimiento: qa 17 → 16, done 6 → 7; el total sigue
en 65 porque es un movimiento, no un ticket nuevo.

Jurgen 2026-08-28 (alta, hallazgo de la MISMA corrida de device): `groups-pending-member-can-open-group`
entra en `backlog/` con prioridad **high** — estando **pendiente de aprobación**, B veía el grupo en su
lista y **al tocarlo podía entrar y verlo**. Owner: está mal. **No se dobla** dentro del ticket del aviso
(allí el defecto era que el aviso no se retiraba DESPUÉS de aprobar, y hoy se retiró) ni se reusa
`groups-join-intent-reconciler` (allí el miembro no nacía). Sin implementación y sin causa inventada: lo
único medido del mecanismo es que entregar **grupo + roster** a un pendiente es **intencional** en el DDL
(`supabase-groups-staging.ddl:125`, `:153`, comentario en `:814`) mientras el contenido financiero **no**
baja (`:817`, `:819`, `:821`) ⇒ lo que queda abierto es una **decisión de producto**, y choca con
`guest-decline-has-no-screen`, que trata el mismo hecho como problema de copy. Counts tras el alta en
este árbol (ya con ghost-tx cerrado y deleted-group-detail dentro): backlog 29 → 30, total 64 → 65.

Jurgen 2026-08-28 (cierre): `groups-approval-banner-stays` pasa a `done/` con **PASS del owner** (Lima,
**TF 2.1 build 12**): B se une, ve «1 solicitudes pendientes» y el aviso de esperar al admin, A aprueba y
**B —sin forzar el cierre de la app ni reabrirla— ve irse solos el aviso y el mensaje naranja**, con el
grupo normal y 2 miembros activos. Es el escenario que ningún test podía cerrar, y **medido**: el fix
`479e8e81` es ancestro de `f4cf3d2b` («Build 12 para TestFlight de 2.1») ⇒ el binario que probó el owner
lleva el código. **Fuera del PASS**, escrito en el ticket: el rechazo y la contra-prueba del tercer
miembro no se corrieron hoy (tienen unit, no device), B no era install limpia, y esto **no** cierra al
hermano `groups-join-intent-reconciler`, que sigue en `qa/`. Counts medidos tras el movimiento: qa 18 →
17, done 5 → 6; el total no se mueve por el cierre porque es un movimiento, no un ticket nuevo.

Jurgen 2026-08-28 (cierre): `groups-ghost-tx-on-delete` pasa a `done/` con **PASS en device del owner**
(Lima). Dos teléfonos, mismo grupo, **TF 2.1 build 12**: A crea un gasto al 50/50, B lo ve en el grupo y
en su Panel, A lo borra y en B —sin reabrir A— el gasto se va del grupo **y** la transacción puenteada
desaparece del Panel, sin huérfana atascada. Dos comprobaciones posteriores del mismo día completan la
liquidación: A la registra y B la ve sin force-quit con los balances cuadrando, y después A la borra y en
B desaparece sin dejar balances colgados (las dos PASS). ⇒ la clase de fantasma del ticket queda cubierta
en device para las **dos** entidades del reporte original, gasto y liquidación. **Lo que estos PASS no
cubren, escrito en el ticket:** los dos borrados salieron de **A**, así que el sentido contrario (borrar
desde B, el bug era bidireccional) **no se corrió**; en la liquidación el reporte llega al grupo y a los
balances, no al Panel de B; no hay PASS de cola C (d)(e) más allá de esos tres escenarios; no hubo subida
nueva a TestFlight y A7/M5 sigue en HOLD.
Counts medidos tras el movimiento: qa 19 → 18, done 4 → 5; el total sigue en 64 porque es un
movimiento, no un ticket nuevo. `groups-background-emitter-no-upload` ya está `done/` (PR 41); este
cierre no lo toca.

Jurgen 2026-08-28 (alta): `groups-deleted-group-detail-stays-open` entra en `backlog/` con prioridad
**high** — reporte de device del owner (TF 2.1 build 12, teléfono A, Lima): tras borrar el grupo el
detalle **se quedó abierto**, y el grupo solo desapareció de la lista después de tocar Atrás. En esta
corrida el botón de borrar **sí** apareció. Sin implementación y **sin causa declarada**: el reporte no
distingue si lo que quedó delante era la sheet de Ajustes o el detalle en push, y esa distinción es la
que decide dónde va el fix. Contraste con `groups-leave-rpc-error-10`: esa es otra corrida y otro
teléfono (B), donde falló **salir** con «GroupsRPCError 10» y no había botón de borrar — ese ticket no
se toca aquí, y **medido**: hoy no tiene fichero en este árbol (vive en una PR abierta a `2.1`, sin
mergear). **Medido** en el alta, sobre `2175e53e`: el índice previo (63 filas) coincidía exactamente
con disco en id y status en las 63, y el único delta era este ticket nuevo (backlog 28 → 29, total
63 → 64). **Re-medido** tras traer `2.1` @ `7ddf87fc` a esta rama —que ya incluye el cierre del emisor
de abajo—: 64 filas ↔ 64 ficheros, sin huérfanos por ninguno de los dos lados, y los counts de arriba
son los de este árbol ya fusionado. Nota de alcance: siguen abiertas otras PRs a `2.1` que mueven
tickets de estado; nada de ellas está incorporado aquí, así que estos counts volverán a moverse a
medida que entren.

Jurgen 2026-08-28 (cierre): `groups-background-emitter-no-upload` pasa a `done/` por **QA device PASS**
del owner — dos teléfonos, TF 2.1 build 12: A crea el gasto de grupo y se va al Home de iOS sin
force-quit, B lo ve en ~30 s sin que A se reabra. El código ya estaba en `2.1` vía PR 19, así que **este
cierre es QA, no un fix nuevo**, y hoy no hubo subida a TestFlight. Counts medidos tras el movimiento,
ya con el alta de `fx-partial-rate-rows-silent-1to1` dentro: in-progress 10 → 9, done 3 → 4; el total
sigue en 63 porque es un movimiento, no un ticket nuevo. (El 63 de esa línea es el de su propio árbol:
en esta rama el total es 64 con el alta de arriba dentro.)

Jurgen 2026-08-28 (alta): `fx-partial-rate-rows-silent-1to1` entra en `backlog/` con prioridad
**high** — familia FX del audit de Frank sobre `2.1` @ `68a7221c` (filas de tasas incompletas +
conversión 1:1 que se declara exacta). Es **un** ticket, no tres: las tres caras (lectura, cambio de
moneda preferida, `persistRate`) comparten el predicado `rateExists` vs `rateHasAllCurrencies`. Sin
implementación. **Medido** antes y después: el índice previo (62 filas) coincidía exactamente con
disco en id y status en las 62; el único delta era este ticket nuevo. Counts tras el alta:
backlog 27 → 28, total 62 → 63.

Jurgen 2026-08-27 (cierre): `notifications-not-delivered-testflight` pasa a `done/` como **no es bug de
entrega** — en el device el permiso de notificaciones de iOS estaba en OFF y la app no volvió a pedirlo.
**No es PASS**: no hubo cambio de código ni subida. Counts medidos tras el movimiento: in-progress
11 → 10, done 2 → 3; el total sigue en 62 porque es un movimiento, no un ticket nuevo.

Jurgen 2026-08-27: la línea de counts anterior decía `backlog 26 · in-progress 11 · qa 18` (= 60) con
61 filas en el índice y 61 ficheros en disco. **Medido**: índice y disco coincidían exactamente
(mismo id y mismo status en los 61); lo único desalineado era esa línea. Corregida a los valores
medidos, ya con este ticket dentro.

Jurgen 2026-08-26: `groups-cloud-mode-hardening-v1`, `groups-cloud-identity-loss-on-migrate`, `device-handover-groups-leak` are **discarded** (CloudKit dead / no remaining written AC). Not PASS. Not `done/`.

## Origin map (YalaWiki → tickets/)

| origin | destination |
|--------|-------------|
| Bugs/crash-inbox-convertir-a-gasto-grupo-draft-borrado.md | tickets/done/inbox-crash-convert-to-group-expense.md |
| Bugs/groups-notif-actualizo-atribuye-al-pagador-no-al-autor.md | tickets/done/group-notif-credits-payer-not-editor.md |
| Bugs/grupos-enlace-de-invitacion-cinco-causas-un-solo-mensaje.md | tickets/in-progress/invite-link-five-causes-one-message.md |
| Bugs/grupos-invitado-el-no-no-tiene-pantalla.md | tickets/in-progress/guest-decline-has-no-screen.md |
| Bugs/grupos-recorrido-del-invitado-codigo-muerto-y-docblock-caducado.md | tickets/in-progress/guest-journey-dead-screens.md |
| Bugs/ok_applepay-shortcut-ios27-warm-launch-datos-vacios.md | tickets/qa/applepay-shortcut-warm-launch-empty-data.md |
| Bugs/ok_siri-intent-dual-container-refactor.md | tickets/qa/siri-intent-dual-container.md |
| Bugs/prefs-cinco-keys-synced-suben-y-no-vuelven.md | tickets/in-progress/prefs-synced-keys-upload-not-download.md |
| Bugs/qa_cloud-fx-rates-blob-dos-caras.md | tickets/qa/cloud-fx-rates-blob-two-faces.md |
| Bugs/qa_cloud-tx-epoca-relaciones-huerfanas.md | tickets/backlog/cloud-tx-epoch-orphan-relations.md |
| Bugs/qa_groups-aprobacion-no-retira-banner.md | tickets/done/groups-approval-banner-stays.md |
| Bugs/qa_groups-join-intent-reconciler.md | tickets/qa/groups-join-intent-reconciler.md |
| Bugs/qa_groups-tab-no-perf-patterns.md | tickets/backlog/groups-tab-missing-panel-perf.md |
| Bugs/qa_groups-tx-fantasma-al-borrar-gasto-de-grupo.md | tickets/done/groups-ghost-tx-on-delete.md |
| Bugs/qa_invite-backend-mudo-config-stale.md | tickets/qa/invite-backend-stale-config.md |
| Bugs/qa_pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega.md | tickets/qa/scheduled-payments-notif-dedup.md |
| Bugs/qa_storekit-appgroup-siri-pro-gate.md | tickets/qa/storekit-appgroup-siri-pro-gate.md |
| Bugs/qa_welcome-copy-acusa-al-dueno-de-traer-datos-ajenos.md | tickets/in-progress/welcome-copy-blames-owner.md |
| Bugs/qa_welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo.md | tickets/qa/welcome-start-fresh-wipes-before-ask.md |
| Bugs/qa_widget-snapshot-sin-sello-la-visita-pisa-los-datos-del-dueno.md | tickets/qa/widget-snapshot-visitor-overwrites-owner.md |
| Bugs/reentrada-la-vuelta-cuenta-como-instalacion-nueva.md | tickets/in-progress/reentry-counts-as-fresh-install.md |
| Bugs/secundaria-canal-apagado-la-visita-borra-los-grupos-del-dueno.md | tickets/in-progress/secondary-groups-off-wipes-owner.md |
| Bugs/secundaria-la-visita-escribe-en-el-dominio-del-dueno.md | tickets/in-progress/secondary-visitor-writes-owner-domain.md |
| Bugs/secundaria-salida-de-la-invitada-bloqueo-permanente-y-outbox-de-grupos.md | tickets/in-progress/secondary-guest-exit-lock-and-outbox.md |
| Bugs/tf-suscripcion-exito-sin-pro.md | tickets/done/subscription-success-without-pro.md |
| Bugs/ux_update-banner-appstore-criterios-y-forzado.md | tickets/qa/update-banner-appstore-criteria.md |
| Backlog/alerts-huerfanos-detras-de-fullscreencovers.md | tickets/backlog/orphan-alerts-behind-fullscreen-covers.md |
| Backlog/debounce-transactions-imported-from-sync-observer.md | tickets/backlog/debounce-sync-imported-transactions.md |
| Backlog/future_yala-android.md | tickets/backlog/yala-android.md |
| Backlog/groups-busqueda-interna.md | tickets/backlog/groups-in-group-search.md |
| Backlog/groups-emisor-segundo-plano-no-sube.md | tickets/done/groups-background-emitter-no-upload.md |
| Backlog/groups-import-splitwise-tricount.md | tickets/backlog/groups-import-splitwise-tricount.md |
| Backlog/groups-invitado-moneda-region-red-muerta.md | tickets/backlog/groups-guest-currency-from-region.md |
| Backlog/groups-presupuesto-de-grupo.md | tickets/backlog/groups-budget.md |
| Backlog/groups-reconexion-poda-o-recableado.md | tickets/backlog/groups-reconnect-prune-or-rewire.md |
| Backlog/groups-recordatorio-liquidacion.md | tickets/backlog/groups-settlement-reminder.md |
| Backlog/groups-registrar-gasto-por-chat-voz.md | tickets/backlog/groups-log-expense-via-chat-voice.md |
| Backlog/groups-resumen-compartible-exportable.md | tickets/backlog/groups-shareable-summary.md |
| Backlog/insights-calculator-iconlookup-precomputed.md | tickets/backlog/insights-precomputed-icon-lookup.md |
| Backlog/p20-13_records-standalone-discrepancy.md | tickets/backlog/records-standalone-amount-discrepancy.md |
| Backlog/p20-15_comparativa-kpi-vs-curva-descuadre.md | tickets/done/trends-comparison-kpi-vs-curve.md |
| Backlog/qa_apppreferences-lavado-general.md | tickets/qa/apppreferences-rewritten-on-launch.md |
| Backlog/qa_groups-endurecimiento-modo-nube-v1.md | tickets/discarded/groups-cloud-mode-hardening-v1.md |
| Backlog/qa_grupos-nube-perdida-identidad-y-migracion.md | tickets/discarded/groups-cloud-identity-loss-on-migrate.md |
| Backlog/qa_handover-dispositivo-grupos-fuga.md | tickets/discarded/device-handover-groups-leak.md |
| Backlog/qa_inbox-convertir-a-gasto-de-grupo.md | tickets/done/inbox-convert-draft-to-group-expense.md |
| Backlog/qa_prefs-dominio-por-sesion-secundaria.md | tickets/qa/prefs-domain-per-secondary-session.md |
| Backlog/trends-insight-card-v2-bullets.md | tickets/backlog/trends-insight-card-v2-bullets.md |
| Ideas/idea-fx-pnl-card.md | tickets/backlog/fx-pnl-education-card.md |
| Ideas/Insights exportable basado en comando insights de Claude con diseño muy basico y amigable.md | tickets/backlog/exportable-insights.md |
| Ideas/Integración con Apple Watch.md | tickets/backlog/apple-watch.md |
| Ideas/Notificaciones Smart con IA.md | tickets/backlog/smart-ai-notifications.md |
| Ideas/Predicción de gasto dentro de línea de gasto en flujo de caja.md | tickets/backlog/cashflow-spend-prediction.md |
| Ideas/Presupuesto adaptado a ingreso o egreso (?).md | tickets/backlog/budget-tied-to-income-or-expense.md |
| Ideas/Presupuestos recomendados con IA.md | tickets/backlog/ai-recommended-budgets.md |
| Ideas/Rediseño cuentas en Panel.md | tickets/backlog/panel-accounts-redesign.md |
| Ideas/Tracking de ahorros.md | tickets/backlog/savings-tracking.md |
| Ideas/Tracking de deudas.md | tickets/backlog/debt-tracking.md |
| Backlog/modo-nube/qa_MODO-NUBE-SPEC-CONSENT-GRUPOS.md | tickets/qa/groups-consent-door-spec.md |
| Backlog/modo-nube/qa_rescate-pull-grupos-descartados.md | tickets/qa/rescue-discarded-groups-pull.md |
