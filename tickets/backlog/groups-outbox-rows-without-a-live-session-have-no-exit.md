---
id: groups-outbox-rows-without-a-live-session-have-no-exit
status: backlog
priority: medium
area: "settings, groups, modo-nube"
created: 2026-09-11
source: "review adversarial del paso 9 (`session-exits-one-verb-per-session`), lente de celdas"
---

# Si mi sesión de grupos caducó con cambios sin subir, no puedo cerrar sesión hasta volver a entrar

## El síntoma, en lenguaje de usuario

Anoté gastos de grupo sin conexión y mi sesión caducó. Toco «Cerrar sesión» y Yala me dice que mi sesión
caducó y que vuelva a entrar. Si puedo entrar, bien: se suben y ya puedo cerrar. Si no puedo —borré la cuenta
desde otro sitio, perdí el acceso a ese correo—, no hay forma de cerrar sesión en este teléfono.

## Lo que hace el código desde el paso 9

- El cierre de la privada (C) y el de solo grupos (F) no descartan filas vivas de `GroupSyncOutbox`: sin
  sesión no se pueden subir, y el boot-wipe borra sync-meta, que es donde viven. Se bloquea con
  `BlockReason.sessionExpired` y el aviso `groups.errors.sessionExpired`.
- Es el criterio del ticket («nunca descarta») y la D15 del paso 9: los grupos no tienen salida de emergencia.
- Antes del paso 9, la fila «Salir de Yala en este dispositivo» purgaba el outbox en silencio.

## Lo que falta decidir (Jürgen)

1. ¿Hay una salida para quien no puede volver a entrar? Por ejemplo, un descarte avisado que cuente las
   filas, como la salida de emergencia del export.
2. El outbox no tiene dueño: si la persona entra con OTRA cuenta, las filas se suben firmadas por esa cuenta.
   ¿Se sellan con el `userID` que las escribió?

## Criterios de aceptación

- [ ] Decisión escrita sobre las dos preguntas.
- [ ] Si hay descarte: aviso con el número, segundo gesto, canario.
- [ ] Si hay sello: una fila de otra cuenta no se sube nunca (test en las dos direcciones).

## 2026-09-15 · la celda de la nube entra en esta población

Desde `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (decisión 3A de Jürgen), el cierre de
una cuenta **en la nube** también enseña `groups.errors.sessionExpired` cuando el push de grupos no tiene
sesión. Antes decía «revisa tu conexión». El bloqueo ya existía y sigue igual: lo que cambia es que ahora dice
por qué. Con esto, la pregunta 1 de arriba aplica a las cuatro celdas del cierre (C, D, E y F), no solo a C y F.

**Y la pregunta 2 gana urgencia.** El aviso empuja a volver a entrar, y en la nube, con la sesión borrada por el
SDK, la única puerta es «Nuevo grupo» en la pestaña Grupos. Ese botón lleva al inicio de sesión de Grupos, y al
firmar `CloudIdentityRoutingLogic` devuelve `.continueGroupsSetup` sin mirar qué cuenta entra. Si entra otra,
estas filas podrían subirse a su nombre. Leído en el código, sin ejecutar. Ver
`cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`.
