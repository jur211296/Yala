---
id: groups-transfer-leave-write-ahead
status: backlog
priority: low
area: groups
created: 2026-09-06
updated: 2026-10-08
source: review adversarial de groups-owner-transfer-and-leave (2026-09-06)
---

# «Transferir y salir» desde Ajustes no persiste su fase: si el proceso muere a mitad, no hay resume

## Qué le pasa al usuario

Confirmo «Transferir y salir». La app cede el grupo y, justo después, se cae la red (o cierro la app,
o el sistema me la mata). El grupo ya no es mío en el servidor, pero **sigo dentro**. Nadie lo retoma
solo: hasta que yo no vuelva a abrir los ajustes del grupo y lo intente otra vez, me quedo a medias.

## Qué se midió

`GroupService.transferOwnershipThenLeave` nació dentro de `GroupBatchLeaveOrchestrator`, que le daba
dos cosas que la pantalla de ajustes **no** tiene:

1. **Write-ahead de fase.** El batch graba `.inProgress` ANTES de la red y su resume (boot/foreground)
   re-ejecuta la acción congelada. Desde Ajustes no queda ningún rastro persistido de «ya transferí,
   me falta salir».
2. **Gate de quiescencia** (`isImportQuiescent`) antes de tocar el `mainContext` compartido. Este medio
   punto **no es nuevo ni exclusivo**: `leaveGroup` y `softDelete` desde Ajustes tampoco lo tienen, y el
   header del orquestador ya lo llama «el mismo residual acotado del tap único».

## Por qué no es urgente (y por qué tampoco es nada)

El estado **es recuperable sin pérdida**: el RPC es idempotente-suave (un segundo `transfer` con el
owner ya cambiado devuelve `{already: true}` sin tocar nada), y al reabrir la pantalla la acción vuelve
a ofrecerse y completa. Lo que falta es que ocurra **solo**.

Y desde el arreglo de [[groups-owner-transfer-and-leave]], la ventana ya no es peligrosa: `isOwner`
local baja en cuanto el transfer devuelve OK, así que en esa ventana la pantalla ofrece «Salir» —la
acción correcta— y ya no «Eliminar», que era la que podía destruir el grupo del nuevo dueño.

## Criterio de hecho (AC)

- [ ] La transferencia desde Ajustes deja un intent durable equivalente al del batch, o se decide
      explícitamente que no lo lleva y por qué.
- [ ] Si lo lleva: resume en boot/foreground, y un test que mate el proceso entre transfer y leave.

## Relacionados

- [[groups-owner-transfer-and-leave]] — el ticket que expuso esta primitiva a una segunda superficie.

## Medido en 2.1 (triage 2026-10-08)
- `GroupSettingsView.transferAndLeave` (`GroupSettingsView.swift:883-905`) llama directo a `GroupService.transferOwnershipThenLeave` (`GroupService.swift:907`), sin grabar fase.
- El único camino con write-ahead sigue siendo el batch (`GroupService.swift:792`, vía `GroupBatchLeaveOrchestrator`).
- Baja a `low`: recuperable sin pérdida al reabrir los ajustes, y desde el arreglo del padre la ventana ofrece «Salir».

Triage 2026-10-08: abierto · medium → low · GroupSettingsView.transferAndLeave sigue llamando a transferOwnershipThenLeave sin intent durable ni resume; el estado es recuperable a mano y sin pérdida.
