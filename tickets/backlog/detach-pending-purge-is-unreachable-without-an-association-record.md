---
id: detach-pending-purge-is-unreachable-without-an-association-record
status: backlog
priority: low
area: "grupos, sesiones"
created: 2026-09-17
source: "review adversarial de `fresh-start-keeps-a-groups-session-that-migrate-promotes` (lente de puertas, H8), 2026-09-17"
---

# Si soltar la cuenta de grupos falla a medias sin asociación guardada, «Terminar de soltar» no sale nunca

## El problema, en lenguaje de usuario

En «Dónde viven tus datos» toco «Desasociar» en Grupos. Se cierra la sesión, pero el borrado de los grupos del teléfono
falla. La pantalla no me ofrece terminarlo: mis grupos siguen en el teléfono y la sección me ofrece asociar una cuenta,
como si no hubiera pasado nada.

## Lo medido (2026-09-17, leído en el código)

- `CloudSessionSignOut.detachGroupsAccount` resuelve la cuenta con `GroupsAccountAssociation.shared.associatedSub ??
  CloudAuthService.shared.currentUserID`. Si el borrado local falla, arma `GroupsDetachPendingPurge.arm(sub:)` con ese `sub`.
- Quien ofrece terminar (`GroupsAssociationSection.hasPendingPurge`) y el reintento (`retryDetachPurge`) preguntan
  `GroupsDetachPendingPurge.isArmed(for: GroupsAccountAssociation.shared.associatedSub)`. Sin registro, `associatedSub` es
  `nil` e `isArmed` devuelve `false` (`GroupsAssociationDetach.swift`): la marca existe y nadie la ve.
- El estado «sesión viva sin registro» es el de un teléfono que pasó por «Empezar desde cero» con la sesión anterior viva,
  y el de una sesión anterior al paso 10 cuyo registrador no llegó a escribir. **Desde el 2026-09-17 el aviso de «Migrar a
  la nube» manda ahí a desasociar** (`fresh-start-keeps-a-groups-session-that-migrate-promotes`).
- Qué hace fallar el borrado local no está medido: el `save()` de `purgeGroupsDomainForDetach`.

## Por dónde va

Que el reintento y la sección comparen con la marca por sí misma cuando no hay registro (la sesión ya está cerrada, así
que la condición «la sesión viva no es la de la cuenta pendiente» se cumple), o que el gesto guarde el registro antes de
armar.

## Criterios de aceptación

- [ ] Un desasociar que falla a medias sin asociación registrada ofrece terminar de soltar la cuenta.
- [ ] El reintento sigue sin poder borrar los grupos de una cuenta distinta de la que quedó a medias.
