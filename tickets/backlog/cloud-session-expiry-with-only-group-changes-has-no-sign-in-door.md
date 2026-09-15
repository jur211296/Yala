---
id: cloud-session-expiry-with-only-group-changes-has-no-sign-in-door
status: backlog
priority: medium
area: "modo-nube, groups, sesión, settings"
created: 2026-09-15
source: "medición del encargo `cloud-signout-collapses-a-groups-session-expiry-into-permanent` (2026-09-15), matizada por una lente adversarial"
---

# En la nube, «vuelve a iniciar sesión» no dice dónde, y a veces no hay dónde

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube, mi sesión caducó y tengo un gasto de grupo sin subir. Toco «Cerrar sesión» y Yala me
dice «Tu sesión caducó. Vuelve a iniciar sesión e inténtalo de nuevo.» Busco «Iniciar sesión» y no lo encuentro
en ningún sitio.

## Lo medido (leído, sin ejecutar)

Depende de lo que hizo el SDK con la sesión:

- **Si la borró** (el servidor rechazó la renovación con un código terminal), la única puerta es **«Nuevo
  grupo»** en la pestaña Grupos. Con grupos en la lista, ese botón está (`GroupsContainerView.swift:148-150`), y
  sin sesión lleva al inicio de sesión de Grupos (`GroupCreateRoutingLogic.route` → `.needsSignIn` →
  `.presentGroupsSignIn`). Nada en el botón dice que sirva para volver a entrar.
- **Si sigue guardada** y la renovación falla, no hay ninguna puerta. Es sobre todo quien está sin conexión, y
  ahí lo que sobra es el texto: `groups-push-reads-an-offline-token-refresh-as-a-session-expiry`.
  **Desde el 2026-09-15 esta rama ya no le llega a quien solo está sin conexión:** con la sesión guardada, el canal
  lee pasajero el token que no llega. Sigue llegando cuando el servidor rechaza con 401 un token que el SDK da por
  bueno —p. ej. sin App Attest (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`)—, y ahí sigue sin haber
  puerta: «Nuevo grupo» enruta por `hasSession` y abre el formulario.

Lo que no ofrece volver a entrar:

- **El banner de Almacenamiento.** Es el «Iniciar sesión» de un sync parado en la nube, pero exige cambios
  **personales** pendientes (`CloudMigrationController.refreshSyncBanner`). Con solo cambios de grupos no sale.
- **«Tu cuenta de Yala»**: sus salidas son cerrar sesión, volver a iCloud y borrar la cuenta (`YalaAccountLogic.Exit`).
- **La sección de grupos de Almacenamiento**: en la nube es `.sameAccountAsPersonal`, que solo informa
  (`GroupsAssociationLogic.swift:69-70`).
- **El estado vacío de Grupos** (`signInToView`): solo sale con la lista vacía.

**Riesgo sin medir.** Al volver a firmar por «Nuevo grupo», `CloudIdentityRoutingLogic` devuelve
`.continueGroupsSetup` para un dispositivo en la nube (`CloudIdentityRoutingLogic.swift:185-191`) sin mirar qué
cuenta entra. Si entra otra, el outbox de grupos pendiente podría subirse a su nombre. Es la pregunta 2 de
`groups-outbox-rows-without-a-live-session-have-no-exit`, y el aviso nuevo empuja justo hacia ahí. No se leyó
`GroupsSignInView` ni su guard entre cuentas.

## Lo que hay que decidir (Jürgen)

1. **Un aviso propio para la sesión caducada con un botón «Volver a entrar»**, que abra el inicio de sesión de
   Grupos. Tiene que ser un aviso aparte: un botón condicional dentro del `.alert` compartido de Ajustes es el
   patrón que `.claude/rules/swiftui-ds.md` tiene medido como «rompe la app».
2. **Ensanchar el banner de Almacenamiento** a los cambios de grupos pendientes con la sesión caída. La puerta ya
   existe y re-firma con la cuenta guardada (`signInToResumeSync`), pero la persona tiene que ir a buscarla.
3. **Solo texto**: que el aviso diga dónde se entra.

Recomendación: la 1, que pone la puerta donde está el consejo. Antes, medir que ese inicio de sesión exige la
misma cuenta.

## Criterios de aceptación

- [ ] Decisión escrita.
- [ ] Con la sesión borrada y solo cambios de grupos pendientes, hay una puerta visible que diga que es para volver
      a entrar.
- [ ] Volver a entrar con OTRA cuenta no sube las filas pendientes de la anterior (test en las dos direcciones).

## Relación con otros tickets

- `cloud-signout-collapses-a-groups-session-expiry-into-permanent` — el aviso que manda a buscar esta puerta.
- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el mismo aviso cuando la causa era la red
  (cerrado en el canal de sincronización el 2026-09-15).
- `groups-outbox-rows-without-a-live-session-have-no-exit` — quien no puede volver a entrar de ninguna forma, y la
  pregunta de a nombre de quién suben las filas.
