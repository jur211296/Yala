---
id: personal-clock-ahead-wins-every-conflict-until-real-time-catches-up
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-26
updated: 2026-09-26
source: "`personal-clock-rollback-wedges-the-drain-forever` (2026-09-26): el precio del arreglo, gemelo personal de `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`"
---

# Un teléfono que tuvo la hora adelantada gana los conflictos de tus datos en la nube hasta que la hora real lo alcanza

## El problema, en lenguaje de usuario

Adelantas la hora de tu iPhone una semana, apuntas algo y la devuelves. Durante esa semana, lo que cambies en ese iPhone
gana siempre a lo que cambies en tu otro dispositivo en los mismos datos (un movimiento, una cuenta, una preferencia): si
editas ese movimiento desde el iPad, tu cambio desaparece en el siguiente refresco, sin aviso. Con la hora puesta años
adelante, dura años.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Desde `personal-clock-rollback-wedges-the-drain-forever` el drain personal (`CloudSyncEngine.appendRow`) y las
  preferencias (`PrefsOutbox.enqueue`) estampan con `HLCClock.sendLocal`, que sigue al reloj lógico del teléfono aunque
  vaya por delante de la hora real. Es lo que conserva el orden de sus propios cambios. Antes ese teléfono dejaba de subir
  nada; ahora sube, con HLC del futuro.
- El reloj lógico del canal personal vive en `SyncCursor.clockLatestHLC`; el de las preferencias, en el `lastIssuedHLC` de
  `PrefsOutbox`. Mientras la hora real no los alcance, todo lo que ese teléfono emita va por delante del resto.
- **El otro dispositivo puede quedarse divergente, no solo perder** (review adversarial, lente HLC): B baja la edición de
  A (HLC `L+1`, un mes por delante); su `receive` lanza por la deriva y su reloj no avanza, pero la fila se aplica. B edita
  esa fila después de haberla visto, estampa con su hora real, pierde el LWW en el servidor, recibe `applied`/`noop` y
  purga su fila; como el servidor no cambió, B no vuelve a bajar nada y sigue mostrando su valor mientras el servidor y A
  tienen el de A. Dura hasta que alguien vuelva a editar la fila. En las preferencias es más directo: `PrefsOutbox` no
  tiene `receive`. Que la fila perdedora no mueva `server_seq` es inferido (el RPC no está en el repo).
- No se midió si el backend personal pone tope a un HLC futuro. Y con grep no aparece quién borra
  `SyncCursor.clockLatestHLC` al cerrar sesión (en Grupos, `CloudSessionSignOut.purgeGroupsSyncState` borra el
  `GroupSyncCursor`): si nadie lo borra, el adelanto pasa a la siguiente cuenta que entre en ese iPhone.
- Mientras el reloj lógico va más de 5 min por delante, `receiveRemoteClock` rechaza cada HLC remoto (su guarda de
  deriva) y deja un rastro `cloudSyncClockReceiveRejected` por fila aplicada. No pierde datos —el reloj local ya va por
  delante de ellos—, pero ensucia ese canario durante todo el adelanto.

## Qué habría que decidir

- Lo mismo que en Grupos, y conviene decidirlo una vez para los dos canales: ¿tope en el servidor a un HLC futuro, o se
  acepta el precio? Recortar rompe el orden propio; rechazar vuelve a dejar el teléfono sin subir.
- ¿Silenciar el canario de `receive` cuando la deriva la causa el reloj propio y no el remoto?

## Criterios de aceptación

- [ ] Decisión escrita, común con `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up`.
- [ ] Medido si el backend personal limita un HLC futuro, y qué borra `SyncCursor.clockLatestHLC`.
- [ ] Test: el dispositivo que pierde un conflicto contra un HLC adelantado converge al valor del servidor.
