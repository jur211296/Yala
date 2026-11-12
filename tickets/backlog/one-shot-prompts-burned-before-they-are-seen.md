---
id: one-shot-prompts-burned-before-they-are-seen
status: backlog
priority: low
area: notifications
created: 2026-10-30
updated: 2026-10-30
source: inventario del ticket notices-come-out-one-after-another-by-priority (sesión S27f, leído en el código, sin medir en simulador)
---
# La hoja de permiso de notificaciones y la tarjeta de avisos de grupo se dan por vistas antes de verse

Qué ve la persona: si la hoja «Activa las notificaciones» no llega a presentarse (UIKit la rechaza), no se vuelve a pedir nunca; la tarjeta «Avisos de grupo» se marca vista en cuanto se mide, aunque Grupos se monte sin que la lista se vea.

Leído: `NotificationPrimerMoments.claim` quema `seenKey` antes de presentar (`NotificationPrimerMomentLogic`); `GroupNotificationsOptInCard` escribe `hasSeenGroupsNotificationPrompt = true` al medirse. La regla del repo (`swiftui-ds.md`, Presentaciones) dice que los one-shots se queman en el `onAppear` del contenido real.

Hecho cuando: las dos marcas se queman al verse, con test.
