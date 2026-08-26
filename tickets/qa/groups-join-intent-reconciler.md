---
id: groups-join-intent-reconciler
status: qa
priority: high
area: "groups, sync, cloudkit, onboarding"
created: 2026-07-11
updated: 2026-08-26
source: YalaWiki/Bugs/qa_groups-join-intent-reconciler.md
---


> [!bug] Corrida real (Pia, 2026-07-11): aceptó un enlace de invitación de semanas y (1) al owner JAMÁS le llegó la solicitud de aprobación, (2) recibió la notif espuria "Jür se unió al grupo", (3) la UI le dijo "¡Todo listo!" sin member real. Root cause + fix en branch `2.0.5` (plan `~/.claude/plans/abundant-hatching-hippo.md`).

# Validar en TestFlight: join intent + reconciliador + baseline de notificaciones

## Implementación

### 2026-07-12 — `dea3e61b` (branch 2.0.5)

**Resumen:** las 3 piezas del plan aterrizaron en un commit único (43 archivos +2731/−90): join intent persistente + reconciliador (bugs 1+3 de raíz), baseline de notifs del primer import + autoexclusión (bug 2), onboarding honesto con tracker observable + banner + l10n, hardening del enqueue silencioso.

**Archivos clave:**
- `Yala/Services/Groups/PendingJoinStore.swift` (NUEVO) — intent multi-entry por zona, TTL 7d, cap 8.
- `Yala/Services/Groups/GroupJoinReconciler.swift` (NUEVO) — consume intents en 4 triggers; inyectable para tests.
- `Yala/Services/Groups/GroupJoinIntentTracker.swift` (NUEVO) — @Observable, fases reales para UI; retry() por razón.
- `Yala/App/Logic/GroupJoinReconcileLogic.swift` + `GroupInviteOnboardingLogic.swift` (NUEVOS) — decisiones puras.
- `SplitSyncManager.swift` — acceptShare persiste intent + reporta al tracker; hook en processPendingRemoteChanges; handler `didFetchRecordZoneChanges` (antes no-op) cierra el baseline; clasificación con firma nueva; markPendingChange/Deletion con log+canario.
- `SplitGroup.swift` — `initialMemberImportStartedAt` LOCAL-only (sin translator ⇒ sin deploy CloudKit).
- `GroupInviteOnboardingView.swift` — reescrita sobre step computado; `detectFinalStep` eliminado.

**Decisiones técnicas:** store separado de `PendingInviteStore` (ciclos de vida incompatibles — aquel se limpia al presentar, este solo con member asegurado); trigger del baseline = `didFetchRecordZoneChanges` por zona (inmune a multi-batch) + ventana 15min auto-sane; supresión también de pending en initialImport; el tracker reemplaza el alert de error que quedaba TAPADO por el cover.

**Tests:** 78 nuevos/extendidos (suite 4150/367 verde) + XCUI `GroupInviteOnboardingUITests` 5/5.

## Qué se arregló (resumen)

1. **Member del invitado jamás nacía** si la zona compartida no había bajado al momento del accept (ventana export-only ≥60s; `acceptShare` lo saltaba EN SILENCIO y nadie lo reintentaba). → Ahora el accept persiste un **join intent** (`PendingJoinStore`, TTL 7d) que `GroupJoinReconciler` consume en 4 triggers (accept / fetch remoto / boot / foreground) hasta crear y exportar el `SplitMember` (pendingApproval).
2. **Notif espuria "X se unió"** en el primer import de una zona recién unida (members preexistentes clasificaban como nuevos). → Autoexclusión por identidad + baseline `SplitGroup.initialMemberImportStartedAt` (set al insertar el grupo por fetch, clear en `didFetchRecordZoneChanges`, ventana 15 min auto-sana).
3. **Onboarding honesto**: el "¡Todo listo!" solo aparece con member confirmado (`GroupJoinIntentTracker.phase == .active`); estados nuevos joining / "está tardando" (salida digna a los 20s) / error con Reintentar; banner de continuidad en el tab Grupos.

## Guion device cross-device (2 devices / 2 usuarios, SOLO TestFlight)

CKShare no funciona en sim. Device A = owner (cuenta full), device B = invitado FRESH (install limpia, ideal cuenta iCloud secundaria).

### Caso 1 — el timing exacto del bug (aceptar dentro de los primeros 60s)

- [ ] A: crear grupo nuevo + generar enlace. Enviarlo a B.
- [ ] B (install fresh): abrir el enlace e ir RÁPIDO — tap "Unirme" en cuanto aparezca el onboarding (dentro de la ventana export-only).
- [ ] B: la UI muestra **"Conectando con tu grupo…"** (spinner) — NUNCA "¡Todo listo!" inmediato. Si tarda >20s, aparece "Está tardando un poco más de lo normal" con CTA "Seguir a la app".
- [ ] B: al materializar la zona (~1-2 min máx), la pantalla avanza SOLA a **"Esperando aprobación"** (o el banner del tab Grupos pasa de "Conectando…" a "Esperando aprobación" si cerró el cover).
- [ ] **A: llega la notificación "X quiere unirse"** y el badge de solicitudes en el detalle del grupo — ESTE era el bug 1.
- [ ] A: aprobar → B pasa a activo (cover abierto avanza solo; si cerrado, el grupo funciona al abrirlo).
- [ ] **B: NO recibió ninguna notif "Jür se unió al grupo"** durante su primer import — ESTE era el bug 2.

### Caso 2 — kill-app durante la ventana

- [ ] B (otro grupo/enlace): aceptar, tap "Unirme" y MATAR la app antes de que el grupo aparezca.
- [ ] B: relanzar → el reconciliador de boot (o foreground) crea el member solo; A recibe la solicitud sin que B toque nada.

### Caso 3 — regresión del owner

- [ ] A: sus notifs "X quiere unirse" siguen llegando normal (el baseline NO aplica a grupos creados localmente).
- [ ] A: reinstalar la app → durante el re-import inicial NO llega un flood de notifs "se unió" por los members históricos (baseline en el private engine).

### Console.app (device B, categoría SplitSync, streaming ANTES de reproducir)

- `JoinReconcile[acceptShare]: zone ... not local yet — waiting` (el skip que antes era silencioso)
- `JoinReconcile[remoteInsert|boot|foreground]: member ensured for zone ... status=pendingApproval` (el fix trabajando)
- Ausencia de `SplitSync markPendingChange DROPPED` (canario de enqueue perdido)

### Telemetría (TelemetryDeck)

- `groupJoinIntentPersisted` / `groupJoinIntentReconciled` (trigger,status) / `groupJoinIntentDeferred` (reason)
- `groupJoinIntentExpired` debe ser 0 (>0 = un invitado quedó fuera pese a aceptar — CANARIO)
- `cloudkitGroupEnqueueDroppedNoEngine` debe ser 0

## Remediación del caso de Pia (sin release)

Que reabra el enlace de invitación con el build actual: la zona ya sincronizó, el flujo existente crea su member pendingApproval y al owner le llega la solicitud.

## Referencias

- Commits en branch `2.0.5` (join intent + baseline + onboarding honesto + XCUI `GroupInviteOnboardingUITests`).
- Coverage: `qa/coverage-index.json` áreas `groups-pending-approval-reconnect`, `groups-notifications-deeplinks`, `groups-cross-device-sync` (lastVerified 2026-07-11).
- Gotcha nuevo en CLAUDE.md: acciones post-accept de CKShare = intents persistentes reconciliables, nunca one-shot.

## 2026-08-17 — re-medición contra 2.0.5

Árbol: `jur211296/Yala` rama `2.0.5`, HEAD `012cabe0`. **No se ejecutó QA hoy.** `status` / `qa-status` se dejan (`needs-testing`: el ticket es mixto).

**Premisa FALSE / obsoleta (D):** el escenario CKShare / export-only ≥60 s / `acceptShare` que materializa la zona. `Yala/Services/Groups/SplitSyncManager.swift` → **404**. `AppBootstrapper.handleInviteLink` case `.ckShare`: comentario «Fase 3: este canal ya no existe» → `showInviteError` + canary `ckShareChannelRemoved`. `GroupInviteChannelRoutingLogic.route` sigue devolviendo `.ckShare` si `isBackendLink == false` (el comentario del helper aún dice «camino CKShare intacto»); el **transporte** ya no une.

También D, porque dependían de ese transporte:

- Caso 1 del guion («Unirme en los primeros 60 s», ventana export-only).
- Caso 3 del guion en su lectura CK (baseline `didFetchRecordZoneChanges` / flood de notifs del private engine). **No se afirma** que el baseline de notifs del canal **backend** esté cerrado ni que haya que reescribirlo aquí.
- Console.app categoría SplitSync (`JoinReconcile[acceptShare]`, `SplitSync markPendingChange DROPPED`).
- Telemetría `cloudkitGroupEnqueueDroppedNoEngine`.

**Sigue vivo (no es D):** `PendingJoinStore`, `GroupJoinReconciler`, `GroupJoinIntentTracker` (commit `dea3e61b` existe). `GroupJoinReconciler.Trigger` = `acceptShare` / `remoteInsert` / `boot` / `foreground`. El trigger `acceptShare` ya no tiene transporte CK; boot y foreground **sí** tienen call-site (`AppBootstrapper` / `ContentView`).

**REMAINS (C):** e2e backend cross-device — la solicitud llega al owner, onboarding honesto, sin notif espuria «se unió». 2 devices + APNs. Caso 2 (kill-app + reconciliar al relanzar) **puede** seguir aplicando al join backend vía boot/foreground; no se re-corrió.

No buscar ventana export-only. No cerrar el ticket. Joan revisa el nombre.

migrated from YalaWiki Bugs/qa_groups-join-intent-reconciler.md @ 1934e8ad
