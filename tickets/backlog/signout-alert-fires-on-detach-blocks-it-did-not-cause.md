---
id: signout-alert-fires-on-detach-blocks-it-did-not-cause
status: backlog
priority: medium
area: "modo-nube, settings, groups"
created: 2026-09-13
source: "review adversarial de `groups-killswitch-403-blocks-detach-forever`, lentes de producto y de sync"
---

# Soltar la cuenta de grupos enciende además «No pudimos cerrar tu sesión»

## El problema, en lenguaje de usuario

Pido soltar mi cuenta de grupos desde Ajustes. Falla por cambios sin subir, y la sección me lo dice con
su aviso propio: «No pudimos soltar la cuenta». Un tercio de segundo después me sale ENCIMA un segundo
aviso, «No pudimos cerrar tu sesión», sobre un cierre de sesión que yo no pedí.

## Lo medido (2026-09-13)

- `detachGroupsAccount` escribe **la misma** `CloudSessionSignOut.phase` que el cierre de sesión
  (`CloudSessionSignOut.swift:214` → `pushGroupsForSignOut` → `:885`).
- `ProfileView` escucha esa fase (`.onChange`) y sigue montada, porque la pantalla de almacenamiento se
  abre desde ella. `presentSignOutBlock` enciende su alert para `.permanent`, `.sessionExpired`,
  `.channelPaused` y `.transient`.
- El corte que ya existe (`ProfileView.swift:156`) solo cubre `.bridgeUnreadable` y `.detachBusy`, que
  son los dos motivos EXCLUSIVOS del desasociar. Los compartidos no se pueden distinguir por el motivo.
- Es preexistente para `.permanent`/`.sessionExpired`/`.transient`; `.channelPaused` (2026-09-13) lo
  hereda y lo hace más visible, porque ahora los dos avisos dicen la misma frase.

## Lo que se espera

El discriminador correcto es **el gesto que puso la fase**, no el motivo. `DetachOutcome` ya viaja por
retorno justo porque la fase la leen seis sitios ajenos; la pieza que falta es que el coordinador diga
también quién la escribió, o que el desasociar deje de usar `phase` para su bloqueo.

Segundo efecto medido, del mismo agujero: el `.alert` de `ProfileView` no tiene `onDismiss`, así que si
UIKit descarta la presentación por tener el anchor ocupado, el flag se queda en `true` y el aviso salta
más tarde, al volver al Perfil (`.claude/rules/swiftui-ds.md`).

## El colateral cambió de texto el 2026-09-16, y a peor (medido)

Ticket `signout-pending-copy-says-wait-seconds-when-offline`. Al separar las dos mitades de lo pasajero, el
caso **más común del desasociar** —fallar sin red— dejó de salir por `.transient` y pasa por
`.uploadRetryLater`, que `ProfileView.swift:198` enciende en el mismo alert genérico. Consecuencia para quien
solo pidió soltar su cuenta de grupos:

| | Aviso propio de la sección | Aviso colateral de Ajustes |
|---|---|---|
| Antes | «No pudimos soltar la cuenta» | «Un momento más» — impreciso, pero **no nombra ningún gesto** |
| Ahora | «No pudimos soltar la cuenta» | **«No pudimos cerrar tu sesión»** — nombra un gesto que no se pidió |

El agujero no nace ahí: el alert colateral salía antes y sale ahora, y el discriminador sigue siendo el que
este ticket describe. **Lo que cambia es que el texto pasa de neutro a equivocado**, y por eso conviene
saberlo al priorizar: la población que lo ve es la misma que el otro ticket vino a atender.

**Lo que NO es el arreglo, comprobado el 2026-09-16:** meter `.uploadRetryLater` en el corte de
`case .bridgeUnreadable, .detachBusy: break`. Ese motivo también lo produce el cierre de sesión de verdad, y
ahí el aviso SÍ tiene que salir — cortarlo por motivo deja al cierre sin su aviso. Y el coordinador sigue sin
publicar el gesto: `phase` y `waitingForPending` son lo único observable
(`CloudSessionSignOut.swift:62` y `:68`), así que la pieza que falta es la que este ticket ya pide.
