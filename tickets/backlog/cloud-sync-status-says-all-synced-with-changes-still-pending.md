---
id: cloud-sync-status-says-all-synced-with-changes-still-pending
status: backlog
priority: medium
area: "modo-nube, sync, ajustes"
created: 2026-09-16
updated: 2026-09-16
source: "decisión D11 del Paso 0 de `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-16), ampliada por su review adversarial"
---

# «Dónde viven tus datos» dice «Todo sincronizado» con cambios que todavía no han subido

## El problema, en lenguaje de usuario

Tengo mis datos en la nube. Me quedo sin conexión y apunto dos gastos. Abro Ajustes → «Dónde viven tus datos» y la
sección de sincronización enseña un check verde con «Todo sincronizado». Mis dos gastos todavía no están en la nube.

## Lo medido (leído en el código, sin ejecutar)

- `StorageSettingsView.syncStatusSection` tiene tres ramas: el aviso del attest terminal, `syncNeedsSignIn` y un `else`
  que pinta el check verde. Todo estado que las dos primeras no enumeran cae al `else`.
- `CloudMigrationController.refreshSyncBanner` solo pone `syncNeedsSignIn` con el runtime en `.stoppedUntilSignIn` y
  filas vivas en el outbox. Con el runtime en `.running` y en backoff, `pendingUploadCount` se queda a 0 y la sección no
  mira el outbox.
- **Quién cae ahí:** cualquiera sin red con cambios pendientes y el token vigente (el push falla por transporte, que es
  `.transient`), o con la verificación de App Attest caducada (el motor sale en su puerta). **Desde el 2026-09-16 también
  quien pierde la sesión sin red mientras esa verificación sigue en caché**: hasta ese día el runtime paraba con
  `stopUntilSignIn` y la sección pedía «Inicia sesión para subir N cambios», que tampoco era verdad y sin red no se podía
  hacer (`personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`, decisión D11).
- **Y quien tiene la red bien pero el gateway le rechaza el token de App Attest** (401 `yala_attest_required`: un build
  que no manda la cabecera, el reloj atrasado, el servidor). Desde el mismo día ese 401 es pasajero y tampoco para el
  motor. **Ahí no se cura al volver la red**, porque la red funciona: dura lo que dure la causa. Lo encontró la review
  adversarial y es lo que sube la prioridad a `medium`.
- Sin red, en cambio, se cura solo: con la red de vuelta el siguiente ciclo sube y el check vuelve a ser cierto.
- Familia del mismo `else`: `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date` (la nube congelada) y
  `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` (el attest, ya cerrado).

## Lo que hay que decidir (Jürgen)

1. Contar las filas vivas del outbox siempre que el modo sea `.cloud` y, con alguna pendiente y el motor sin
   `.completed` reciente, enseñar «N cambios esperando conexión» (copy nuevo en los 16 idiomas).
2. Quitar el check verde cuando haya filas vivas, sin texto nuevo (la sección se queda sin estado).
3. Dejarlo: es transitorio y se cura al volver la red.

Recomendación: la 1. Es la única que no afirma nada falso, y el conteo ya existe (`livePendingUploadCount`). Para quien
el gateway le rechaza el attest, el texto de la 1 («esperando conexión») culparía a la red: si se elige, decidir también
si esa población lleva su propia frase (`cloud-attest-notice-does-not-cover-a-gateway-rejected-token`).

## Criterios de aceptación (si se elige la 1)

- [ ] Sin red y con cambios pendientes, la sección no enseña «Todo sincronizado» (test de la lógica de la sección).
- [ ] Con el outbox vacío y el último ciclo completado, sí (test en la dirección contraria).
- [ ] Las ramas del attest y de `syncNeedsSignIn` conservan su prioridad.
