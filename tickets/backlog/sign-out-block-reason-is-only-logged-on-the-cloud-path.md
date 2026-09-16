---
id: sign-out-block-reason-is-only-logged-on-the-cloud-path
status: backlog
priority: low
area: "sesión, observabilidad"
created: 2026-09-16
updated: 2026-09-16
source: "review adversarial de `signout-pending-copy-says-wait-seconds-when-offline` (2026-09-16)"
---

# En tres de los cuatro cierres, el log no dice por qué se bloqueó

## El problema, en lenguaje de usuario

Éste no lo sufre nadie usando la app. Lo sufre quien intente entender, con los logs delante, por qué a alguien
no le dejó cerrar sesión. El rastro dice **cuántos** cambios quedaban sin subir, pero no **qué** aviso vio la
persona, así que dos incidentes muy distintos —«no hay red» y «el guardado aún se asienta»— se leen igual.

## Lo medido (2026-09-16)

- `CloudSyncBreadcrumb.signOutGroupsBlocked(reason:)` existe y lleva el slug del motivo
  (`BlockReason.breadcrumbSlug`), pero **tiene un solo emisor**: `CloudSessionSignOut.swift:1021`, el paso 2
  del cierre en la NUBE.
- Los otros tres caminos —el cierre solo-grupos, el «equipo» y el desasociar— solo emiten
  `signOutPushBlocked(pending:)` (`:1175` y `:1180`, entre otros), que lleva la cifra y nada más.
- Es preexistente, y hasta el 2026-09-16 pesaba poco: en esos caminos lo pasajero era un solo motivo.

## Por qué importa desde hoy

El ticket `signout-pending-copy-says-wait-seconds-when-offline` partió ese motivo en dos —la subida que no
llegó al servidor y el guardado que aún se asienta— y les dio **textos distintos y políticas de reintento
distintas** (uno se avisa al momento, el otro gasta 45 s). Justo en los tres caminos donde el log no
distingue cuál salió. Si mañana alguien reporta «me dijo que esperara y no pasaba nada», el rastro no puede
contestar si vio un aviso o el otro.

## Lo que se espera

Emitir `signOutGroupsBlocked(reason:)` también en `pushGroupsForSignOut`, en las dos salidas que fijan la
fase (`.surfacePermanent` y `.surfaceTransient`), con el motivo **ya resuelto** — el mismo criterio que usa
el paso 2 de la nube, que lo emite después de traducir precisamente para que el log diga lo que la persona
vio y no lo que el canal devolvió.

Ojo al desasociar: comparte esa función, así que heredaría el breadcrumb. Eso es correcto —el bloqueo existió
igual— pero conviene que el slug o el evento permitan distinguir el gesto, o el dashboard contará cierres de
sesión que nadie pidió. Es el mismo discriminador que pide
`signout-alert-fires-on-detach-blocks-it-did-not-cause`.

## Relación con otros tickets

- `signout-pending-copy-says-wait-seconds-when-offline` — de donde sale.
- `canarios-y-breadcrumbs-sin-emisor` — el hermano ancho. Aquí el emisor existe; lo que falta es que lo
  llamen los otros tres caminos.
- `signout-alert-fires-on-detach-blocks-it-did-not-cause` — comparte la pieza que falta: el coordinador no
  publica qué gesto puso la fase.
