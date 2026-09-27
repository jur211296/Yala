---
id: prefs-change-is-dropped-when-the-outbox-cannot-take-it
status: backlog
priority: low
area: "modo-nube, sync, preferencias"
created: 2026-09-26
updated: 2026-09-26
source: "residual de `prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it` (2026-09-26), D2 de su Paso 0"
---

# Un cambio de preferencia hecho mientras la cola no lo acepta no llega a tus otros dispositivos

## El problema, en lenguaje de usuario

Si cambias una preferencia justo cuando el teléfono no consigue leer la cola de preferencias pendientes, el cambio se
queda en este teléfono y no sube. Tus otros dispositivos no lo ven hasta que vuelvas a cambiar esa preferencia.

## Por qué pasa (leído el 2026-09-26)

- `PreferenceSyncService.enqueuePref` escribe el valor local y llama a `PrefsOutbox.enqueue`. Si el `enqueue` lanza, el
  `catch` solo deja log (y, con `.readFailed`, el rastro `prefsOutboxUnreadable step=enqueue`): nadie lo reintenta.
- Desde `prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it`, un archivo ilegible hace lanzar
  `.readFailed` sin escribir, a propósito: así se conservan todas las pendientes. El precio es este cambio suelto.
- Lo mismo pasa hoy con `.persistFailed` (la escritura falla) y con `.clockFailed` (año fuera de rango).

## Qué haría falta decidir

- Si se reintenta el cambio (en memoria, con su `now` original, hasta el siguiente ciclo del runtime), cómo se cruza con
  un teardown de sesión (`purgeAll`) y con un cambio de dueño: el reintento no puede subir un valor a otra cuenta.

## Criterios de aceptación

- [ ] Un cambio que el outbox no aceptó sube en cuanto el outbox lo acepta, con el HLC de cuando se hizo.
- [ ] Un cambio de dueño o un teardown entre medias lo descarta.
