---
id: welcome-shows-a-takeover-exit-as-a-connection-error
status: backlog
priority: low
area: "modo-nube, bienvenida"
created: 2026-09-24
updated: 2026-09-24
source: "sesión de `displaced-migration-leader-keeps-uploading-after-a-takeover` (2026-09-24), hallazgo al recorrer las superficies de la salida"
---

# La bienvenida dice «Revisa tu conexión» cuando otro dispositivo tomó el relevo de la activación

## El problema, en lenguaje de usuario

Entro en mi cuenta desde la bienvenida y el teléfono recibe el relevo de una activación que otro dejó a medias. Si este
teléfono se queda luego más de una hora sin conexión y un tercero toma el relevo, la activación sale con el motivo «otro
dispositivo con tu cuenta tomó el relevo». En Almacenamiento ese es el texto que se ve; en la bienvenida sale el error
genérico, que habla de la conexión. La conexión no es el problema.

## Lo medido (2026-09-24, en el código)

- `CloudWelcomeSignInFlow.phase(for:…)`, rama `.failed`: solo distingue `adoptClaimExit` y
  `forwardStepExit == .lineageUnproven`. Cualquier otro `forwardStepExit` —`otherDevice` incluido— cae a
  `.error(retryable: true)`.
- `otherDevice` lo journalean dos salidas: el techo de `cutover(.pending)` (ya antes de este ticket) y, desde
  `displaced-migration-leader-keeps-uploading-after-a-takeover`, la puerta del lease de la subida y la verificación.
- Alcanzable solo en un adopt de la bienvenida que recibió el relevo (`created` sobre una cuenta con datos) y luego lo
  perdió: raro, pero es un texto falso.

## Candidata (sin medir)

Una fase propia en la bienvenida con el texto de Almacenamiento (`storage.failed.stepOtherDevice`), molde de
`.lineageExit`: una sola función elige el texto en las dos pantallas.

## Criterios de aceptación

- [ ] En la bienvenida, la salida `otherDevice` muestra el mismo texto que Almacenamiento, no el de la conexión.
