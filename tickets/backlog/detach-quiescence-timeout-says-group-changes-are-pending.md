---
id: detach-quiescence-timeout-says-group-changes-are-pending
status: backlog
priority: low
area: "modo-nube, settings, groups"
created: 2026-10-02
source: "review adversarial de `detach-saves-the-personal-graph-outside-the-quiescence-window` (lente de consumidores)"
updated: 2026-10-08
---

# Cuando iCloud aún está bajando datos, el desasociar dice «quedan cambios de tus grupos sin subir»

## El problema, en lenguaje de usuario

Si desasocio mientras iCloud termina de bajar mis datos, tras un minuto el aviso dice «Quedan cambios de tus grupos sin
subir. Inténtalo de nuevo en un momento». No queda nada sin subir: lo que pasa es que el iPhone aún está recibiendo
datos de iCloud. Y el mismo hecho sale con otro texto si me pilla un poco más tarde: «No pudimos revisar los
movimientos de tus grupos» (el bloqueo de la segunda puerta, desde el 2026-10-02).

## Lo leído en el código (sin ejecutar)

- La primera puerta de quiescencia vive en `CloudSessionSignOut.attemptGroupsOnlyClose`, y su tope sale como
  `.blocked(pendingCount: 0, reason: .transient)`; el desasociar pinta `.transient` con `detachBlockedTransient`.
- La segunda, la de `writeDetachUnderQuiescence`, sale con `.bridgeUnreadable` a propósito, porque ahí el push-all ya
  drenó.
- Ninguna de las dos deja rastro (canario ni breadcrumb) cuando agota el tope: no se sabe cuántas veces pasa en la
  flota. `.sessionNotClosed`, en cambio, sí tiene canario.
- Mientras la segunda puerta espera, el texto bajo el spinner sigue diciendo «Guardando tus cambios pendientes…»
  (`waitingForPending` no se baja hasta el `defer`).

## Lo que se espera

Un motivo propio para «iCloud aún está bajando tus datos», con su texto, que salga desde las dos puertas del
desasociar; y un canario fuera de `#if DEBUG` cuando la espera agota el tope. Es copy nuevo en los 9 idiomas: decisión
de producto.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSessionSignOut.attemptGroupsOnlyClose` sigue devolviendo `.blocked(pendingCount:…, reason: .transient)` cuando `awaitPersonalQuiescenceForGroupsSignOut` agota el tope, y `GroupsAssociationSection` lo pinta con `detachBlockedTransient`.
- Sigue sin canario ni breadcrumb al agotar el tope de quiescencia; no hay commits sobre la quiescencia del desasociar desde el 2026-10-02.
- Sigue pendiente la decisión de copy (motivo propio «iCloud aún está bajando tus datos»).

Triage 2026-10-08: abierto · low → low · el tope de quiescencia sigue saliendo como `.transient` («quedan cambios sin subir») y sin canario; texto inexacto, reintentar funciona.
