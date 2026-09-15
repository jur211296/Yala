---
id: groups-phone-that-never-attests-is-told-to-retry-forever
status: backlog
priority: medium
area: "groups, attest, sesión, copy"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` (2026-09-15)"
---

# Un teléfono que nunca consigue App Attest oye «inténtalo en un rato» para siempre

## El problema, en lenguaje de usuario

Mi teléfono no consigue App Attest, y esperar no lo arregla. Grupos no sube nada. Cada aviso me dice que lo intente en
un rato; lo intento durante días y nada cambia. Y si tengo cambios de grupos sin subir, no puedo cerrar sesión: no hay
forma de salir igualmente.

## Lo medido (leído en el código, sin ejecutar)

- Desde el 2026-09-15 un 401 `yala_attest_required` es pasajero en el canal de Grupos
  (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`). Antes era «Tu sesión caducó», igual de falso:
  volver a entrar tampoco lo arreglaba.
- Lo que ve la persona no distingue un attest que vuelve de uno que no:
  - Cierre en la nube sin cambios personales pendientes: «Los últimos cambios de tus grupos no llegaron al
    servidor…», que invita a intentarlo en un rato.
  - «Equipo», solo grupos, hoja del cambio de Apple ID y puerta de Grupos del Welcome: 45 s de reintentos y «Un
    momento más», que pide esperar unos segundos.
  - Desasociar en Almacenamiento: «Quedan cambios de tus grupos sin subir. Inténtalo de nuevo en un momento.»
  - Salir de un grupo: «No pudimos completar tu salida del grupo. Vuelve a intentarlo en un momento.»
  - Aceptar una invitación: espera y caduca en silencio
    (`groups-join-intent-expires-silently-after-transient-failures`).
- Ninguno de esos cierres ofrece salir sin subir: los cambios de grupos no se descartan nunca.
- El canal personal SÍ tiene un veredicto terminal: `CloudSyncRuntime.performCycle` clasifica el fallo del attest con
  `AttestSyncGate` y, agotados los reintentos, para con el canario `cloudSyncBlockedByAttestUnavailable` y el banner
  de que este dispositivo no puede sincronizar. En `.cloud` conviven los dos mensajes: el banner dice que no puede, y
  el cierre de sesión dice que se intente en un rato.
- Sin medir: cuántos teléfonos están así, y qué errores de `AppAttestError` o `DCError` son de verdad permanentes. La
  clasificación de `AttestSyncGate` es el punto de partida.

## Lo que hay que decidir (Jürgen)

1. Llevar a Grupos el veredicto terminal del canal personal: tras varios fallos de attest, un aviso propio que diga
   que este teléfono no puede sincronizar grupos, en lugar de «en un rato».
2. Además de lo anterior, una salida para cerrar sesión en ese caso que avise de que los cambios de grupos sin subir
   se pierden. Choca con la regla de no descartarlos nunca.
3. Dejarlo, y medir antes cuántos teléfonos hay así.

## Relación con otros tickets

- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — de donde sale.
- `signout-pending-copy-says-wait-seconds-when-offline` — el texto de lo pasajero, que esta población no puede cumplir.
- `groups-join-intent-expires-silently-after-transient-failures` — la invitación que caduca.
- `.claude/rules/gateway-attest.md` — la recuperación de la key, la escalera y los dos 401 de la guard.
