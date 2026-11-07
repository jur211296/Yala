---
id: connection-errors-put-the-fix-on-the-user
status: backlog
priority: low
area: "copy, errores"
created: 2026-11-07
updated: 2026-11-07
source: "exploración 2.3 de la mascota Yalitto (docs/ux/mascota-yalitto-2.3/), hallazgo al revisar el estado «error sin culpar»"
---

# Los errores de red dicen «Revisa tu conexión» aunque la app pueda reintentar sola

## Qué pasa

Varias cadenas terminan pidiéndole a la persona que revise su conexión (medido en `es.lproj/Localizable.strings` el
2026-11-07): `subscription.trialOffer.pricesUnavailable` («No pudimos cargar los precios. Revisa tu conexión.»),
`groups.errors.inviteFailed`, `groups.invite.error.body`, `settings.signOutBlockedMessage` y `welcome.cloud.errorBody`.
El primero se ve en `docs/ux/mascota-yalitto-2.3/capturas/07-error-precios.jpg`.

Pone la tarea en la persona aunque el fallo pueda ser del servidor, y no dice si la app lo volverá a intentar. Relacionado:
`welcome-shows-a-takeover-exit-as-a-connection-error` (ahí el problema es otro: la causa ni siquiera es la red).

## Propuesta

Decir qué pasó y qué hará la app: «No pudimos cargar los precios. Reintentamos solos cuando vuelva la conexión», con
«Reintentar» a mano. Solo donde la app de verdad reintenta; si no, el texto no lo promete. Decide Jürgen.
