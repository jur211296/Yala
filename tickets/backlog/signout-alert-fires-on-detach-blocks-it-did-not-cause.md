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
