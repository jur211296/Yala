---
id: es-ar-detach-and-signout-copy-lost-the-voseo
status: backlog
priority: low
area: "l10n"
created: 2026-09-13
source: "review adversarial de `groups-killswitch-403-blocks-detach-forever`, lente de producto"
---

# El copy de cierre de sesión y desasociar está en tuteo dentro de es-AR

## Lo medido (2026-09-13)

`BRAND-VOICE.md` §9.4 declara el voseo verbal **obligatorio** en `es-AR`, y 246 de los 4.129 strings del
locale lo cumplen — la familia `groups.errors.*` incluida: «no podés», «Volvé a intentarlo», «Revisá tu
conexión». Pero las keys que se añadieron después están en tuteo, copiadas de es-419 sin adaptar:

- `groups.errors.sessionExpired` — «Vuelve a iniciar sesión e inténtalo de nuevo.»
- `storage.groups.detachBlockedTransient` — «Inténtalo de nuevo en un momento.»
- `storage.groups.detachBlockedPermanent` — «Revisa tu conexión y vuelve a intentarlo.»
- `storage.groups.detachBlockedSession` — «Entra otra vez y vuelve a intentarlo.»

`groups.errors.channelPaused` (2026-09-13) sí nació en voseo, así que hoy las dos pantallas del bloqueo
mezclan los dos registros según el motivo.

## Lo que se espera

Barrer `es-AR` en busca de la misma deuda —esto es una muestra, no el inventario— y adaptar. Es sólo
gramática verbal: `BRAND-VOICE` §9.4 prohíbe expresamente los modismos.
