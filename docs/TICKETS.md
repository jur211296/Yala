# Tickets

Index of `tickets/`. Folder name **is** `status`. Filename **is** `id` + `.md` (English kebab-case, assigned by Frank).

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

## Index (65)

| id | status | path |
|----|--------|------|
| inbox-crash-convert-to-group-expense | qa | tickets/qa/inbox-crash-convert-to-group-expense.md |
| group-notif-credits-payer-not-editor | qa | tickets/qa/group-notif-credits-payer-not-editor.md |
| invite-link-five-causes-one-message | in-progress | tickets/in-progress/invite-link-five-causes-one-message.md |
| guest-decline-has-no-screen | in-progress | tickets/in-progress/guest-decline-has-no-screen.md |
| guest-journey-dead-screens | in-progress | tickets/in-progress/guest-journey-dead-screens.md |
| applepay-shortcut-warm-launch-empty-data | qa | tickets/qa/applepay-shortcut-warm-launch-empty-data.md |
| siri-intent-dual-container | qa | tickets/qa/siri-intent-dual-container.md |
| prefs-synced-keys-upload-not-download | in-progress | tickets/in-progress/prefs-synced-keys-upload-not-download.md |
| cloud-fx-rates-blob-two-faces | qa | tickets/qa/cloud-fx-rates-blob-two-faces.md |
| cloud-tx-epoch-orphan-relations | backlog | tickets/backlog/cloud-tx-epoch-orphan-relations.md |
| groups-approval-banner-stays | done | tickets/done/groups-approval-banner-stays.md |
| groups-join-intent-reconciler | qa | tickets/qa/groups-join-intent-reconciler.md |
| groups-tab-missing-panel-perf | backlog | tickets/backlog/groups-tab-missing-panel-perf.md |
| groups-ghost-tx-on-delete | done | tickets/done/groups-ghost-tx-on-delete.md |
| invite-backend-stale-config | qa | tickets/qa/invite-backend-stale-config.md |
| scheduled-payments-notif-dedup | qa | tickets/qa/scheduled-payments-notif-dedup.md |
| storekit-appgroup-siri-pro-gate | qa | tickets/qa/storekit-appgroup-siri-pro-gate.md |
| welcome-copy-blames-owner | in-progress | tickets/in-progress/welcome-copy-blames-owner.md |
| welcome-start-fresh-wipes-before-ask | qa | tickets/qa/welcome-start-fresh-wipes-before-ask.md |
| widget-snapshot-visitor-overwrites-owner | qa | tickets/qa/widget-snapshot-visitor-overwrites-owner.md |
| reentry-counts-as-fresh-install | in-progress | tickets/in-progress/reentry-counts-as-fresh-install.md |
| secondary-groups-off-wipes-owner | in-progress | tickets/in-progress/secondary-groups-off-wipes-owner.md |
| secondary-visitor-writes-owner-domain | in-progress | tickets/in-progress/secondary-visitor-writes-owner-domain.md |
| secondary-guest-exit-lock-and-outbox | in-progress | tickets/in-progress/secondary-guest-exit-lock-and-outbox.md |
| subscription-success-without-pro | done | tickets/done/subscription-success-without-pro.md |
| update-banner-appstore-criteria | qa | tickets/qa/update-banner-appstore-criteria.md |
| orphan-alerts-behind-fullscreen-covers | backlog | tickets/backlog/orphan-alerts-behind-fullscreen-covers.md |
| debounce-sync-imported-transactions | backlog | tickets/backlog/debounce-sync-imported-transactions.md |
| yala-android | backlog | tickets/backlog/yala-android.md |
| groups-in-group-search | backlog | tickets/backlog/groups-in-group-search.md |
| groups-background-emitter-no-upload | done | tickets/done/groups-background-emitter-no-upload.md |
| groups-import-splitwise-tricount | backlog | tickets/backlog/groups-import-splitwise-tricount.md |
| groups-guest-currency-from-region | backlog | tickets/backlog/groups-guest-currency-from-region.md |
| groups-budget | backlog | tickets/backlog/groups-budget.md |
| groups-reconnect-prune-or-rewire | backlog | tickets/backlog/groups-reconnect-prune-or-rewire.md |
| groups-settlement-reminder | backlog | tickets/backlog/groups-settlement-reminder.md |
| groups-log-expense-via-chat-voice | backlog | tickets/backlog/groups-log-expense-via-chat-voice.md |
| groups-shareable-summary | backlog | tickets/backlog/groups-shareable-summary.md |
| insights-precomputed-icon-lookup | backlog | tickets/backlog/insights-precomputed-icon-lookup.md |
| records-standalone-amount-discrepancy | backlog | tickets/backlog/records-standalone-amount-discrepancy.md |
| trends-comparison-kpi-vs-curve | done | tickets/done/trends-comparison-kpi-vs-curve.md |
| apppreferences-rewritten-on-launch | qa | tickets/qa/apppreferences-rewritten-on-launch.md |
| groups-cloud-mode-hardening-v1 | discarded | tickets/discarded/groups-cloud-mode-hardening-v1.md |
| groups-cloud-identity-loss-on-migrate | discarded | tickets/discarded/groups-cloud-identity-loss-on-migrate.md |
| device-handover-groups-leak | discarded | tickets/discarded/device-handover-groups-leak.md |
| inbox-convert-draft-to-group-expense | qa | tickets/qa/inbox-convert-draft-to-group-expense.md |
| prefs-domain-per-secondary-session | qa | tickets/qa/prefs-domain-per-secondary-session.md |
| trends-insight-card-v2-bullets | backlog | tickets/backlog/trends-insight-card-v2-bullets.md |
| fx-pnl-education-card | backlog | tickets/backlog/fx-pnl-education-card.md |
| exportable-insights | backlog | tickets/backlog/exportable-insights.md |
| apple-watch | backlog | tickets/backlog/apple-watch.md |
| smart-ai-notifications | backlog | tickets/backlog/smart-ai-notifications.md |
| cashflow-spend-prediction | backlog | tickets/backlog/cashflow-spend-prediction.md |
| budget-tied-to-income-or-expense | backlog | tickets/backlog/budget-tied-to-income-or-expense.md |
| ai-recommended-budgets | backlog | tickets/backlog/ai-recommended-budgets.md |
| panel-accounts-redesign | backlog | tickets/backlog/panel-accounts-redesign.md |
| savings-tracking | backlog | tickets/backlog/savings-tracking.md |
| debt-tracking | backlog | tickets/backlog/debt-tracking.md |
| groups-consent-door-spec | qa | tickets/qa/groups-consent-door-spec.md |
| rescue-discarded-groups-pull | qa | tickets/qa/rescue-discarded-groups-pull.md |
| distribution-balance-kpi-skips-fx | backlog | tickets/backlog/distribution-balance-kpi-skips-fx.md |
| notifications-not-delivered-testflight | done | tickets/done/notifications-not-delivered-testflight.md |
| fx-partial-rate-rows-silent-1to1 | backlog | tickets/backlog/fx-partial-rate-rows-silent-1to1.md |
| groups-deleted-group-detail-stays-open | backlog | tickets/backlog/groups-deleted-group-detail-stays-open.md |
| groups-pending-member-can-open-group | backlog | tickets/backlog/groups-pending-member-can-open-group.md |

Counts by folder: backlog 30 · in-progress 9 · qa 17 · blocked 0 · done 6 · discarded 3 = 65.

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
| Bugs/crash-inbox-convertir-a-gasto-grupo-draft-borrado.md | tickets/qa/inbox-crash-convert-to-group-expense.md |
| Bugs/groups-notif-actualizo-atribuye-al-pagador-no-al-autor.md | tickets/qa/group-notif-credits-payer-not-editor.md |
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
| Backlog/qa_inbox-convertir-a-gasto-de-grupo.md | tickets/qa/inbox-convert-draft-to-group-expense.md |
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
