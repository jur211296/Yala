---
id: groups-drain-that-always-aborts-takes-the-loss-exit-away
status: backlog
priority: low
area: "grupos, sync, modo-nube"
created: 2026-10-05
updated: 2026-10-05
source: "encargo `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy` (2026-10-05): mirar el gemelo de Grupos"
---

# Con el drain de Grupos atascado, el teléfono sin App Attest y la sesión caducada pierden la salida de «perderlos»

## El problema, en lenguaje de usuario

Muy raro. Si este teléfono no consigue preparar para subir un cambio de tus grupos —siempre, no una vez— y además lleva
más de un día sin App Attest, o tu sesión caducó y no puedes volver a entrar, cerrar sesión te dice «no llegaron al
servidor, inténtalo en un rato» cada vez, y desaparece la opción de cerrar sesión perdiendo esos cambios. Esperar no lo
arregla. No se pierde nada; no hay salida.

## Por qué pasa (leído el 2026-10-05; inferido, no ejecutado)

- Es el gemelo de `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`, que arregló el lado
  personal. **El texto de Grupos ya no prometía segundos**: `CloudSignOutFlowLogic.groupsCaptureVerdict` da
  `.uploadRetryLater` («inténtalo en un rato»), no `.transient`. El hueco que queda es solo la salida.
- `CloudSignOutFlowLogic.lossBlockAfterRecapture` cambia el motivo de un bloqueo que abre la salida (`.attestUnavailable`,
  `.sessionExpired`, `.groupsChangesFromAnotherAccount`) por `.uploadRetryLater` cuando la captura no terminó
  (`captureCompleted == false`) o queda espejo sin rehidratar. Está bien para un fallo pasajero: lo que no salió en el aviso
  no se puede aceptar perder. Con un drain que no termina en ninguna vuelta, la salida no vuelve nunca.
- El arreglo personal contó los cambios del History junto a las filas (`PersonalLoss`) y conservó el motivo con el drain
  atascado. Aquí haría falta lo mismo con la lectura del History de Grupos (no existe una sonda de solo lectura como
  `CloudSyncEngine.uncapturedPersonalChangeKeys`), una tercera mitad en `groupsLossRowIDs`/`FreshStartGroupsLoss`
  (filas, espejo y History) y cablearlo en los cierres que suben grupos (`pushGroupsForSignOut`, paso 2 de la nube),
  «Empezar de cero» (`drainGroupsBeforeFreshStart`) y la puerta de Grupos del Welcome. Es otro trabajo, no el mismo arreglo.

## Criterios de aceptación

- [ ] Con el drain de Grupos atascado y el teléfono sin App Attest, el cierre ofrece «Cerrar sesión y perderlos» con una
      cifra que incluye lo que el drain no capturó.
- [ ] Igual con la sesión caducada y con los cambios de otra cuenta.
- [ ] Un fallo pasajero de la captura sigue sin ofrecer la salida (se cura con otro intento).
