---
id: detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait
status: backlog
priority: medium
area: "modo-nube, settings, groups"
created: 2026-10-02
source: "review adversarial de `detach-saves-the-personal-graph-outside-the-quiescence-window` (lente de consumidores)"
---

# Si cierro Almacenamiento mientras el desasociar espera, cerrar sesión deja de funcionar hasta matar la app

## El problema, en lenguaje de usuario

Toco «Desasociar», el spinner se queda girando (sube cambios o espera a que iCloud termine de bajar datos) y cierro
la hoja de Almacenamiento. Si el gesto acaba bloqueado, no veo ningún aviso. Desde entonces «Cerrar sesión» no hace
nada, y si vuelvo a «Desasociar» me dice «Estás cerrando sesión en este momento», que es falso. Solo sale matando la app.

## Lo leído en el código (sin ejecutar)

- `GroupsAssociationSection.apply` escribe `blockedReason` en una vista ya desmontada: el aviso no sale y nadie llama a
  `acknowledgeBlocked()`, así que `CloudSessionSignOut.phase` se queda en `.blocked`.
- `ProfileView` ignora a propósito los motivos propios del desasociar (`case .bridgeUnreadable, .detachBusy,
  .sessionNotClosed: break`), así que tampoco lo reconoce ella.
- Un desasociar nuevo devuelve `.busy` (`guard phase == .idle`) y su aviso, `.detachBusy`, no llama a
  `acknowledgeBlocked()` porque la fase «es de otro».
- Es anterior a 2026-10-02: el push-all ya podía esperar 45-60 s. Ese día la espera de quiescencia antes del puente
  (`writeDetachUnderQuiescence`) añade otra ventana de hasta 60 s con el mismo desenlace.

## Lo que se espera

Que un `.blocked` del desasociar sin pantalla que lo enseñe no deje el coordinador cogido: o la sección lo vuelve a
leer al aparecer y enseña su aviso, o el bloqueo no se queda en la fase compartida cuando nadie lo va a reconocer.
Decidir cuál con el ticket `signout-alert-fires-on-detach-blocks-it-did-not-cause`, que toca la misma fase compartida.
