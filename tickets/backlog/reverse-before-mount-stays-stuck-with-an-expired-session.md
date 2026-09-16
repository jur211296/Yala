---
id: reverse-before-mount-stays-stuck-with-an-expired-session
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
source: "Paso 0 de `reverse-claim-rejection-has-no-way-out-in-the-client` (D11), 2026-09-16: medido en el código al separar el rechazo del claim de la sesión caducada"
---

# Si la sesión de la nube caduca durante «Volver a iCloud», la barra se queda parada sin decir que hay que volver a entrar

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud» y la barra se para al 15 %, al 30 % o al 62 %. No hay mensaje. «Retomar» no cambia nada, y
mientras tanto el teléfono no sincroniza con la nube. Lo que pasa por debajo es que mi sesión de la nube caducó, pero
la pantalla no me lo dice ni me ofrece volver a entrar.

## Por qué pasa (medido el 2026-09-16)

Las fases de la vuelta anteriores al montaje del espejo tratan la sesión caducada como un corte retomable sin evento,
y ninguna deja rastro para la pantalla:

| Fase (barra) | Qué hace con la sesión caducada | Dónde |
|---|---|---|
| `reverseClaimLeader` (15 %) | `return false`, sin evento | `MigrationRunner.driveReverseClaim`, `case .sessionExpired` |
| `reverseDrainAll` (30 %) | la lee como `.transient` | `MigrationWorkExecutor.reverseDrainOnce` |
| `reverseVerify` (50 %) | la lee como `.networkTimeout` y gasta reintentos de red; al tope va a `reverseFailedRollback` con `.reverseRollback`, que con la sesión caducada lanza y queda pendiente | `MigrationWorkExecutor.verify`, `execute(.reverseRollback)` |
| `reverseFreezeBackend` (62 %) | `false`, sin evento | `MigrationWorkExecutor.freezeBackendForReverse` |

Ninguna de esas fases es estable, así que el motor de la nube no corre (`MigrationRuntimeGate.isDomainStablePhase`) y el
aviso de «vuelve a entrar» de Ajustes (`syncNeedsSignIn`) no sale: solo se enciende con el runtime en
`.stoppedUntilSignIn`, y la tarjeta que se pinta es la de progreso. La ida ya separa este caso con
`MigrationRunner.lastClaimBlocker = .sessionExpired`; la vuelta no tiene equivalente.

## Qué no es

No es el rechazo del servidor: eso lo cerró `reverse-claim-rejection-has-no-way-out-in-the-client`, que dejó la sesión
caducada y la red fuera a propósito (la red sí se arregla esperando).

## Criterios de aceptación

- [ ] Con la sesión caducada en cualquiera de las cuatro fases, la pantalla dice que hay que volver a entrar y ofrece
      hacerlo, en vez de una barra muda.
- [ ] Volver a entrar retoma la vuelta desde donde estaba.
- [ ] En `reverseVerify` la sesión caducada no gasta los reintentos de red ni acaba en un fallo con el abort pendiente.
- [ ] Tests por fase, con mutante.

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` — el rechazo del claim, que ya tiene salida.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — la otra cara: leer como caducada una sesión que
  solo está sin red.
