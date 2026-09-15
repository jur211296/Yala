---
id: signout-pending-copy-says-wait-seconds-when-offline
status: backlog
priority: low
area: "sesión, copy"
created: 2026-09-15
updated: 2026-09-15
source: "decisión de Jürgen en `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15): mismo texto en los tres avisos, y lo impreciso a un ticket aparte"
---

# Sin conexión, el aviso de cierre dice «espera unos segundos»

## El problema, en lenguaje de usuario

Tengo cambios de grupos sin subir, estoy sin conexión y toco «Cerrar sesión». Unos 45 segundos después Yala me dice
«Un momento más · Todavía estamos terminando de guardar unos cambios. Espera unos segundos y vuelve a intentarlo.»
Espero, lo intento otra vez y pasa lo mismo: no se está guardando nada, lo que falta es la red.

## Lo medido

- El texto sale para `BlockReason.transient` en Ajustes y en la hoja del cambio de Apple ID (`SignOutBlockedCopy`) y,
  desde el 2026-09-15, también en la puerta de Grupos del Welcome (`WelcomeGroupsGateView`).
- `.transient` junta dos causas que `CadenceOutcome` no separa: el guardado que aún se asienta, que es para lo que se
  escribió «un momento más» (H-2026-07-18-6), y la subida que falla por red, un 5xx o un cortafuegos.
- La nube ya tiene el texto cierto para la segunda causa: «Los últimos cambios de tus grupos no llegaron al servidor…»
  (`.uploadRetryLater`, 2026-09-14).
- **La espera también dice lo que no pasa.** Durante los ~45 s de reintentos (`GroupsSignOutRetryDecision.budgetSeconds`)
  se lee «Guardando tus cambios pendientes…» en Ajustes, en la hoja del cambio de Apple ID y en el desasociar
  (`settings.signOutWorking`, `storage.groups.detachWaiting`), y «Estamos subiendo tus últimos cambios a iCloud…» en
  la puerta del Welcome (`welcome.groups.neutralWorking`). Sin red no se guarda ni se sube nada, y volver a intentarlo
  cuesta otros 45 s.
- El desasociar termina en «Quedan cambios de tus grupos sin subir. Inténtalo de nuevo en un momento.»
  (`storage.groups.detachBlockedTransient`): la misma imprecisión.
- Sin red y con la sesión vigente, esto ya pasaba antes del 2026-09-15. Ese día se sumó quien tiene el token caducado,
  que hasta entonces veía «Tu sesión caducó».

## Lo que hay que decidir (Jürgen)

1. Separar las dos causas en el canal, con un motivo propio para la subida fallida y un texto para cada una.
2. Usar «no llegaron al servidor… inténtalo de nuevo en un rato» para todo `.transient`, sabiendo que también lo verá
   quien solo esperaba a que terminara un guardado.
3. Dejarlo como está.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — de donde sale.
- `cloud-signout-collapses-every-groups-transient-into-permanent` — el texto de la nube para la subida fallida.
