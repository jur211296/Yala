---
id: attest-copy-still-says-the-security-check-our-server-requires
status: done
priority: low
area: "grupos, nube, copy"
created: 2026-10-19
updated: 2026-10-22
source: "lote decidido 2.2 · 04 (L19-18), visto al reescribir el aviso fijo de Grupos"
---

# Otros diez avisos siguen hablando de «la verificación de seguridad que pide nuestro servidor»

## El problema, en lenguaje de usuario

L19-18 reescribió el aviso fijo de la pestaña Grupos para que diga qué pasa y qué hacer («Este teléfono no puede enviar
cambios a tus grupos desde hace un día…»). Los avisos hermanos —al cerrar sesión, al desasociar, al empezar de cero, el
aviso fijo de la nube en Ajustes— siguen diciendo «Lleva más de un día sin conseguir la verificación de seguridad que pide
nuestro servidor», la frase que la auditoría señaló como jerga.

## Lo medido (es-419, 2026-10-19)

`settings.attestTerminalBanner`, `settings.signOutAttestMessage`, `settings.signOutAttestMessageUnknown`,
`settings.signOutAttestBlocked`, `groups.errors.attestUnavailable`, `groups.errors.attestUnavailableSignOutLoss`,
`groups.errors.attestUnavailableSignOutLossUnknown`, `groups.freshStartPending.lossAttest`,
`storage.groups.detachBlockedAttestAndCaptureUnfinished`, `welcome.groups.neutralAttestLossBody` y
`welcome.groups.neutralAttestLossBodyUnknown`. Fuera del alcance de L19-18, que nombraba solo los dos avisos de Grupos.

## Lo que hay que decidir

Si se reescriben con el molde de L19-18 (qué pasó en palabras de la persona + qué hacer), en 16 idiomas.

## Hecho (2026-10-22, lote decidido 2.2 · 15)

Implementada la opción que eligió Jürgen. Red: `YalaTests/UXAudit22Decidido15Tests` y `YalaUITests/Flows/SettingsLote15UITests`.
