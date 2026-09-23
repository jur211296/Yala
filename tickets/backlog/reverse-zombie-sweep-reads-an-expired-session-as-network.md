---
id: reverse-zombie-sweep-reads-an-expired-session-as-network
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-17
source: "review adversarial de `reverse-before-mount-stays-stuck-with-an-expired-session` (2026-09-17), lente de sesión — hallazgo S1"
---

# El barrido de la vuelta a iCloud sigue leyendo una sesión caducada como si fuera red

## El problema, en lenguaje de usuario

Si mi sesión de la nube deja de valer **después** de que la app haya remontado el espejo —mientras limpia lo que quedó
de la época en la nube— la barra se para y no dice nada. Es lo mismo que pasaba antes en las fases anteriores, pero un
paso más tarde.

## Por qué pasa

`MigrationWorkExecutor.sweepZombies` agrupa `case .sessionExpired, .accountUnavailable, .transient: return .transient`,
y `ZombieSweepOutcome` no tiene un caso para la sesión. El runner lo conduce como corte mudo, y
`noteReverseSessionExpiry` solo se llama desde las cuatro fases previas al montaje, así que
`reverseReconcile(.deletingZombies)` no enciende la tarjeta que sí encienden las otras.

`reverse-before-mount-stays-stuck-with-an-expired-session` acotó a propósito a las fases **anteriores al montaje**, que
son las que el ticket nombraba. Esta es la misma forma, en la fase de al lado.

## Qué hay que mirar antes

- **La población es más estrecha**: para llegar aquí el espejo ya montó y la app relanzó, así que la ventana es la
  espera de quiescencia del import más el barrido. Con un corpus grande pueden ser minutos.
- `sweepZombies` pide el JWT por `tombstoneSource.pullPage`, o sea `SyncPullClient`, que ya separa el token ausente sin
  red con `canRenewSession`. El trabajo es de propagación, no de clasificación.
- Conviene decidirlo junto con `reverse-before-mount-has-no-way-to-abandon-the-return`: las dos fases comparten la
  ausencia de salida.

## Criterios de aceptación

- [ ] Con la sesión caducada en el barrido, la pantalla dice que hay que volver a entrar y lo ofrece.
- [ ] Sin red no lo pide.
- [ ] Test con mutante.

## Relacionado

- `reverse-before-mount-stays-stuck-with-an-expired-session` — las cuatro fases anteriores, ya cerradas.

## Otra causa del mismo atasco (2026-09-22)

Desde `apply-overwrites-a-pending-local-write-without-its-guards`, `sweepZombies` también devuelve `.transient`
cuando una tabla no se deja leer (antes daba el barrido por hecho con los zombies vivos). `.deletingZombies`
devuelve `false` sin techo ni `observeReversePreMountStall`, así que con una tabla ilegible para siempre la vuelta
se queda parada en ese punto sin decir nada. Es la misma falta de salida que este ticket; el arreglo debería
cubrir las dos causas.
