---
id: notification-dedup-deletes-all-custom-reminders-but-one
status: backlog
priority: medium
area: "notificaciones"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), hallazgo al margen"
---

# El deduplicador de avisos borra todos los recordatorios personalizados menos uno

## El problema, en lenguaje de usuario

Creo tres recordatorios propios. Un día, al abrir Yala, solo queda uno.

## Lo medido (2026-09-24, leído en el código, sin ejecutar)

- `NotificationService.deduplicateNotifications` (`Yala/Services/NotificationService.swift`, ~L604-612) agrupa TODOS los
  `NotificationItem` por `typeRaw` y borra todos menos el primero del grupo (activo primero).
- Los recordatorios de la persona tienen `typeRaw == "custom"` (default del modelo), así que caen en el mismo grupo.
- Corre en cada arranque (`AppBootstrapper`, paso 6.1) con la quiescencia del import de iCloud.

## Sin medir

- Si hoy se pueden crear varios `custom` desde la UI (si solo existe uno, el bug no se ve). Es lo primero que hay que
  comprobar en la pantalla de avisos.

## Criterios de aceptación

- [ ] Medido si la UI permite más de un aviso `custom`.
- [ ] Si sí: el deduplicador no agrupa los `custom` (solo los tipos de sistema, que se siembran por dispositivo).
