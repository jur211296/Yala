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

## La otra mitad del mismo mecanismo: las hojas de las PESTAÑAS no entran en la matriz (2026-09-15)

Medido en la review de `apple-id-close-blocked-has-no-visible-outcome`. La matriz de readiness del anchor de
`ContentView` solo ve tres hojas de las pestañas: `ownModalVisible = showDowngradeResolution ||
showTrialExpired || activeMilestone != nil` (`ContentView.swift:3008`), publicado como
`isMainTabModalVisible` (`:3015`). **Ajustes no está entre ellas**, y se abre como hoja desde ocho sitios
(`PanelSheetsModifier.swift:57`, `MoreView.swift:115`, Planificación, Grupos, Registros, Estadísticas,
Informes y el propio `ContentView`). `PanelSheetState.hasActivePresentation` sí la cuenta (`:78-79`), pero
solo la lee la puerta del Panel para sus propios intents, no la del shell.

**Qué pasa, inferido y no reproducido:** con Ajustes abierto, un intent del shell drena igual. Por ejemplo,
el aviso del cambio de Apple ID tras volver de Configuración de iOS, el de vaciado remoto o el
`.iCloudMismatch`. El aviso no llega a montar, o se apila encima de Ajustes. Sus redes de presentación lo
reintentan unos 9 s togglando sobre la raíz y lo sueltan con canario (`appleIDCloseNoticeNotPresented`,
`remoteWipeNoticeNotPresented`), así que la sesión no se brickea: se pierde el aviso hasta el arranque
siguiente. Si se apila, `ProfileView` sigue montada debajo y reacciona sola a la fase del coordinador de
cierre: su alert de bloqueo compite con la hoja que lo está enseñando (regla 4 de Presentaciones). La hoja
del cambio de Apple ID ya no se queda sin salida en ese caso (fase `.stopped`), pero el alert de Ajustes
puede quedarse con su flag puesto.

**Dirección:** la del punto (a) de arriba, extendida a las hojas de las pestañas. Que la matriz del shell
lea también «hay una hoja de pestaña presentada», con el mismo cuidado que tuvo `isMainTabModalVisible`:
un blocker pegado de una hoja que no se cerró bien retendría la cola entera.

## Origen

Diferido D3 de `/review-plan` del fix join intent — plan `~/.claude/plans/abundant-hatching-hippo.md`; ticket relacionado `Bugs/qa_groups-join-intent-reconciler.md`.

migrated from YalaWiki Backlog/alerts-huerfanos-detras-de-fullscreencovers.md @ 1934e8ad
