---
id: groups-loop-restart-docs-cite-a-retired-mount-guard
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-15
source: "medición al cerrar `groups-channel-seal-has-no-reachable-producer`"
---

# Los comentarios del re-arranque del canal de Grupos prometen un guard que ya no existe

## El problema, en lenguaje de código

Dos comentarios dicen que `GroupsLoopRestartLogic.shouldStart` incluye el guard «D8» de mount-mismatch
(`secondaryActive && !secondaryMounted`), y que por eso es seguro llamar `GroupsSyncClient.startIfEligible`
a mitad de sesión. Ese guard salió de la tabla el 2026-09-13 con la sesión de visita: la función ya no
tiene esos parámetros.

## Lo medido (2026-09-15, rama `encargo/2026-09-15-groups-channel-seal-has-no-reachable-producer`)

- `Yala/App/Logic/GroupsLoopRestartLogic.swift:6-8`, la cabecera del fichero: «INCLUDING the D8
  mount-mismatch guard that makes MID-SESSION calls safe».
- `Yala/Services/CloudSync/Groups/GroupsSyncClient.swift`, el docblock de `startIfEligible`: la
  enumeración «SSOT de flag/sesión/single-instance/D8» y el párrafo «D8 (H-2026-07-18-4): AHORA es SEGURO
  llamarlo MID-SESSION … `shouldStart` incorpora el guard de mount-mismatch».
- `Yala/App/Views/Shared/GroupsBackendInviteModifier.swift:162`, en el re-arranque post-sign-in: «D8-safe
  por el guard de mount-mismatch». Lo encontró la lente de corrección de esa misma sesión.
- `git show 783a4ec9b -- Yala/App/Logic/GroupsLoopRestartLogic.swift` (`feat(sesiones): la shell deriva
  del eje 1 y se retira la sesión de visita`) borra los parámetros `secondaryActive` y
  `secondaryMounted` y la línea `if secondaryActive && !secondaryMounted { return false }`.

## Por qué importa aunque hoy no rompa nada

Sin sesión de visita no queda la ventana que ese guard cerraba, así que lo probable es que el re-arranque a
mitad de sesión siga siendo seguro, pero por otro motivo. **Eso no está medido.** Quien lea esos
comentarios dará por hecho un guard que no existe: es la misma trampa que tenía el sello del canal, un
mecanismo que parecía cubrir un caso y no lo cubría.

## Y un desajuste más pequeño del mismo loop

El docblock de `GroupsSyncBreadcrumb.groupsLoopStopped` enumera los motivos de parada
(`session-check-failed` / `session-expired` / `account-unavailable` / `cancelled`) y le falta
`channel-disabled`, que `GroupsSyncClient.runLoop` emite cuando para el kill del canal. Es anterior al
retiro del sello. Va aquí porque se arregla en la misma pasada de comentarios.

## Lo que hay que hacer

1. Medir si queda alguna ventana de mount-mismatch alcanzable desde `startIfEligible`. Sin medir, las
   candidatas a mirar primero son dos identidades sobre el store del dueño (quien entra por un grupo en
   ese teléfono) y el swap de persona sin relanzar.
2. Reescribir los comentarios con lo medido: el porqué nuevo de la seguridad, o el hueco con su ticket.

No es una decisión de producto: es documentación que miente sobre una garantía.

## Relación con otros tickets

- `groups-channel-seal-has-no-reachable-producer`: la sesión que lo encontró, al editar el mismo docblock.
  Esa sesión solo quitó «stop» de la enumeración y dejó «D8» como estaba.
- `shell-derives-from-two-session-axes`: el PR que retiró la sesión de visita.
