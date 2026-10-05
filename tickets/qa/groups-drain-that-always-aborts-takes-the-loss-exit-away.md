---
id: groups-drain-that-always-aborts-takes-the-loss-exit-away
status: qa
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

- [x] Con el drain de Grupos atascado y el teléfono sin App Attest, el cierre ofrece «Cerrar sesión y perderlos» con una
      cifra que incluye lo que el drain no capturó.
- [x] Igual con la sesión caducada y con los cambios de otra cuenta.
- [x] Un fallo pasajero de la captura sigue sin ofrecer la salida (se cura con otro intento).

## 2026-10-05 · Entregado

**Qué cambia para la persona.** Si este teléfono no consigue preparar para subir algún cambio de tus grupos —siempre, no una
vez— y además lleva más de un día sin App Attest, tu sesión caducó o esos cambios los apuntó otra cuenta, cerrar sesión ya no
te dice «inténtalo en un rato» para siempre: vuelve el aviso de siempre con «Cerrar sesión y perderlos», y la cifra cuenta
también los cambios que no se pudieron preparar. Igual en «Empezar de cero» y en la puerta de Grupos del Welcome. Un teléfono
normal (con App Attest y sesión) sigue diciendo «inténtalo en un rato», sin salida que pierda nada. Ningún texto nuevo.

**Cómo (decisión de Jürgen del 2026-10-05: «Reintentos espaciados con espera creciente durante varios segundos, mismo
cambio fallando; luego ofrece la salida con la cifra»).** La captura previa a una salida reintenta con esperas crecientes
(`CloudSignOutFlowLogic.groupsExitCaptureRetryDelays`: 0,5 · 1 · 2 · 4 s, 7,5 s en total) y tras cada intento fallido lee
el History que ningún drain capturó (`GroupsSyncClient.uncapturedGroupsChanges`, solo lectura). Solo si el MISMO cambio
sigue fuera en todos los intentos, con el History leído en cada uno, está atascada: el motivo que abre la salida se
conserva, el push-all cicla aunque el outbox esté a 0 para saber la causa, y lo que se pierde son dos mitades —filas y
History— que el aviso cuenta con cifra exacta y lo aceptado cubre por clave (`CloudSignOutFlowLogic.GroupsLoss`,
`CausedLossAcceptance.uncaptured`, `FreshStartGroupsLoss.uncaptured`). Los recuentos pegados al borrado lo releen.
Decisiones en el Paso 0 del encargo y en el PR.

**Lo pasajero nunca abre la salida del atasco**: un fallo que se cura dentro de los reintentos, unos reintentos cortados
(cancelación, import que deja de estar quieto), un History que no se deja leer, lo de fuera que cambia de intento en
intento, y una captura que termina con entradas del espejo fuera del outbox.

## Guion de device-QA

El drain de Grupos solo se atasca con un store que no deja guardar, así que el estado del ticket no se puede provocar en un
iPhone sin un build con un fallo inyectado. Lo fijan los tests unitarios (`GroupsStuckDrainLossExitTests`, los de
`FreshStartGroupsLossExitTests` y `GroupsOutboxOwnershipTests`). Lo que sí se mira en un iPhone de verdad, con un build de
TestFlight y una cuenta con grupos, es que el camino normal no cambió:

1. **Cierre normal con un gasto de grupo recién apuntado.** Abre un grupo, apunta un gasto y, sin esperar, ve a Perfil →
   «Cerrar sesión». Esperado: cierra como siempre, sin espera nueva (los reintentos de la captura solo se dan si el
   primer intento falla).
2. **Sesión caducada con un gasto de grupo pendiente** (una cuenta cuya sesión expiró, o tras borrar la cuenta desde otro
   dispositivo): apunta un gasto en un grupo sin conexión, recupera la conexión y cierra sesión. Esperado: «Tu sesión
   caducó» con la cifra de cambios y «Cerrar sesión y perderlos». Toca «Ahora no»: no se pierde nada.
3. **Teléfono sin App Attest** (si tienes uno con el aviso fijo en la pestaña Grupos): apunta un gasto y cierra sesión.
   Esperado: el aviso del teléfono que no puede sincronizar, con su cifra y «Cerrar sesión y perderlos».
4. **«Empezar de cero» sin nada pendiente** (Welcome → privado con datos en el teléfono → «Empezar de cero»): borra al
   momento, sin pasar por ningún aviso de grupos.

Sin capturas: el cambio solo se ve con el fallo inyectado, y los avisos que vuelven a salir son los de siempre.
