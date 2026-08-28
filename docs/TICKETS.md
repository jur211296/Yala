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

## Index (64)

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
| groups-approval-banner-stays | qa | tickets/qa/groups-approval-banner-stays.md |
| groups-join-intent-reconciler | qa | tickets/qa/groups-join-intent-reconciler.md |
| groups-tab-missing-panel-perf | backlog | tickets/backlog/groups-tab-missing-panel-perf.md |
| groups-ghost-tx-on-delete | qa | tickets/qa/groups-ghost-tx-on-delete.md |
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
| groups-background-emitter-no-upload | in-progress | tickets/in-progress/groups-background-emitter-no-upload.md |
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
| groups-expense-notif-only-on-foreground | backlog | tickets/backlog/groups-expense-notif-only-on-foreground.md |

Counts by folder: backlog 29 · in-progress 10 · qa 19 · blocked 0 · done 3 · discarded 3 = 64.

Jurgen 2026-08-28 (alta): `groups-expense-notif-only-on-foreground` entra en `backlog/` con prioridad
**high** — reporte de device del owner en TF **2.1 build 12**: A crea/edita un gasto de grupo y la
notificación llega a B **solo al abrir la app**, nada mientras B está fuera; a A no le llega (era el
actor). Sin causa declarada y sin implementación: el ticket lleva el mapa **medido** del camino
(la notif de grupo es LOCAL y nace tras el pull —
`GroupsSyncClient.applyPulledPage:1937` → `GroupNotificationService.processRemoteChanges`) y las
hipótesis con su señal discriminante. **No** se declara el silent push roto: no está medido.
No cierra `group-notif-credits-payer-not-editor`, que sigue en `qa/` con una nota del mismo día
(el «A no recibió / B solo al abrir») y **sin** PASS: hoy no consta quién pagaba el gasto, así que el
caso original (editar un gasto pagado por otro) no cuenta como re-ejecutado.
**Medido** antes y después: el índice previo (63 filas) coincidía exactamente con disco en id, status y
ruta en las 63; el único delta es este ticket nuevo. Counts tras el alta: backlog 28 → 29,
total 63 → 64.

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
| Bugs/qa_groups-aprobacion-no-retira-banner.md | tickets/qa/groups-approval-banner-stays.md |
| Bugs/qa_groups-join-intent-reconciler.md | tickets/qa/groups-join-intent-reconciler.md |
| Bugs/qa_groups-tab-no-perf-patterns.md | tickets/backlog/groups-tab-missing-panel-perf.md |
| Bugs/qa_groups-tx-fantasma-al-borrar-gasto-de-grupo.md | tickets/qa/groups-ghost-tx-on-delete.md |
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
| Backlog/groups-emisor-segundo-plano-no-sube.md | tickets/in-progress/groups-background-emitter-no-upload.md |
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
