---
id: es-ar-detach-and-signout-copy-lost-the-voseo
status: discarded
priority: low
area: "l10n"
created: 2026-09-13
source: "review adversarial de `groups-killswitch-403-blocks-detach-forever`, lente de producto"
updated: 2026-10-08
---

Why: Discarded 2026-10-08. Duplicado de `es-ar-storage-groups-block-is-in-tuteo-not-voseo`: el mismo defecto (keys de es-AR copiadas en tuteo desde es-419 por `add-l10n-key.sh`) y la misma tarea (barrer es-AR entero); tres de sus cuatro keys son `storage.groups.*` y siguen en tuteo hoy. Lo que añade (`groups.errors.sessionExpired`) va como fusión al conservado.

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

**2026-09-25:** `groups.errors.sessionExpired` se ve más desde hoy: también lo enseña el paso 1 del cierre en la nube con
cambios personales y la sesión caducada (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).

Triage 2026-10-08: duplicado · low → — · mismo defecto y misma tarea que `es-ar-storage-groups-block-is-in-tuteo-not-voseo`; sus keys siguen en tuteo y se fusionan allí.
