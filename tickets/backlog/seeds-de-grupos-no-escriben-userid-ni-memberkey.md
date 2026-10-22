---
id: seeds-de-grupos-no-escriben-userid-ni-memberkey
status: backlog
priority: low
area: "groups, testing, seeds"
created: 2026-09-08
updated: 2026-10-08
source: barrido de QA en simulador del 2026-09-08 (hallazgo de camino)
---

# Ningún perfil de seed da un heredero, y eso deja media familia de Grupos sin poder probarse

## Qué pasa

`GroupService.swift:1006` cuenta los herederos posibles así:

```swift
let eligibleHeirs = activeCoMembers.filter { $0.userID != nil }
```

Y **ningún perfil de `DevSeedGroups` escribe `userID` ni `memberKey`** en los miembros:

```
grep -c 'userID\|memberKey' Yala/Seed/DevSeedGroups.swift   →   0
```

⇒ `eligibleHeirCount` es **siempre 0** en simulador, para todos los perfiles (`grupos`,
`grupos-invitado`, `grupos-saldado`, `grupos-sin-flag`, `grupos-pendiente`, `solo-grupos`).

## Por qué importa

El offer de salida del dueño (`GroupService.ownerExitOffer`) cae **siempre** en la misma rama,
`.debtArchiveInstead`. La consecuencia práctica es que hay estados que **no se pueden ver en
simulador, y no por culpa del teléfono**:

- **«Transferir y salir» no se pinta nunca.** `canTransfer` exige `eligibleHeirCount >= 1`, así que
  el ticket `groups-owner-transfer-and-leave` está catalogado como device-QA cuando en realidad la
  mitad que no se puede ver es **culpa del seed**. Su otra mitad (el RPC real
  `transfer_group_ownership`) sí es backend, y esa no se arregla aquí.
- Cualquier futuro caso que dependa de distinguir miembros identificados de anónimos hereda el
  mismo agujero.

El efecto secundario es que el escenario «dueño con deuda y sin heredero» es el **único** que los
seeds saben producir — lo cual, por casualidad, es justo lo que
`groups-owner-debt-no-heir-dead-end` necesitaba (verificado en verde el 2026-09-08). O sea que hoy
el seed acierta por accidente en un caso y ciega el complementario.

## Qué haría falta

Poblar `userID` (y `memberKey` donde corresponda) en los miembros activos de al menos un perfil,
o añadir un perfil nuevo tipo `grupos-con-heredero`. Decidir cuál de las dos: tocar los perfiles
existentes cambia el comportamiento de los XCUITest que ya dependen de ellos —hay que comprobar
cuáles— mientras que un perfil nuevo no rompe nada pero suma superficie.

**Ojo con el efecto de bola de nieve:** si se puebla `userID` en los perfiles actuales,
`groups-owner-debt-no-heir-dead-end` deja de reproducirse con `grupos` y su XCUITest —si se
escribe— necesitaría otro perfil. Los dos casos son complementarios y hacen falta los dos.

## Cómo se sabe que está bien

- Un perfil de seed produce `eligibleHeirCount >= 1` y en Ajustes del grupo aparece
  **«Transferir y salir»** con el nombre del heredero.
- Sigue existiendo un perfil que produce `eligibleHeirCount == 0`, para no perder el caso del
  callejón sin salida.

## Medido en 2.1 (triage 2026-10-08)

- `grep -c 'userID\|memberKey' Yala/Seed/DevSeedGroups.swift` sigue en 0.
- Las coordenadas cambiaron. El offer de salida está en `Yala/Services/Groups/GroupService.swift:972-990` y hoy exige
  `userID` **y** `memberKey` no nulos. El conteo por lotes está en `:1006-1011` y exige solo `userID`.
- Los seeds sí marcan `isBackendGroup = true`, así que basta con poblar los dos campos.
- `groups-owner-transfer-and-leave` ya está en `done`: esto es solo tooling de QA, `low`.

Triage 2026-10-08: abierto · medium → low · DevSeedGroups.swift sigue con 0 userID/memberKey y el offer exige userID y memberKey no nulos; el ticket groups-owner-transfer-and-leave ya está en done, así que solo queda el hueco de QA.
