---
id: orphan-alerts-behind-fullscreen-covers
status: backlog
priority: medium
area: "routing, groups"
created: 2026-07-11
updated: 2026-08-26
source: YalaWiki/Backlog/alerts-huerfanos-detras-de-fullscreencovers.md
---


# Alerts huérfanos detrás de fullScreenCovers (mecanismo general)

## Problema

Los alerts ruteados vía `RouterEntryGate` (`.showGroupSyncError`, `.showInviteError`, etc.) se montan en el árbol de `ContentView` — si en ese momento hay un `fullScreenCover` abierto (invite onboarding, welcome flow, reconnect), el alert queda presentado DETRÁS del cover y el usuario jamás lo ve.

Detectado durante el fix del join intent (2026-07-11): `SplitSyncManager.acceptShare` mostraba su error de accept en un alert que el `GroupInviteOnboardingView` (cover) tapaba por completo. ESE flujo ya no depende del alert (el `GroupJoinIntentTracker` publica la fase `failed` y el cover la muestra con Retry), pero el mecanismo general sigue roto para cualquier otro alert que dispare con un cover abierto.

## Posible dirección

- Auditar los `RouterIntent` de tipo alert y decidir por cada uno: (a) diferir el drain mientras `welcomeChainBlockers`/covers estén presentados (el readiness gate ya existe — quizá basta con clasificar estos intents como bloqueables), o (b) presentar el alert DENTRO del cover activo (patrón tracker/estado observable, como quedó el invite onboarding).
- Verificar también los sheets (`.presentGroupReconnect`) — mismo hazard con detents grandes.

## Origen

Diferido D3 de `/review-plan` del fix join intent — plan `~/.claude/plans/abundant-hatching-hippo.md`; ticket relacionado `Bugs/qa_groups-join-intent-reconciler.md`.

migrated from YalaWiki Backlog/alerts-huerfanos-detras-de-fullscreencovers.md @ 1934e8ad
