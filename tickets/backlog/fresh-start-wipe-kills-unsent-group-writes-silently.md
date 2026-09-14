---
id: fresh-start-wipe-kills-unsent-group-writes-silently
status: backlog
priority: medium
area: "groups, modo-nube"
created: 2026-09-13
source: "review adversarial de `groups-only-private-restart-skips-the-wipe-alert`, lente de datos (A5)"
---

# «Empezar de cero» se lleva los gastos de grupo que aún no habían subido, y no lo dice

## El síntoma

Apunté un par de gastos de grupo sin cobertura. Después hice «empezar de cero» en este teléfono. Esos
gastos no llegaron nunca al grupo, y nadie me avisó de que se iban a perder.

## Lo medido (2026-09-13)

`DataWipeService.wipeLocalGroupsDomain` borra las filas de `GroupSyncOutbox` y purga el espejo del App
Group (`GroupsOutboxMirror().purgeAll()`). Las dos cosas son correctas para su propósito —son escrituras
pendientes del humano anterior, firmadas con un JWT que sobrevive al relevo— pero en el camino nuevo de
la puerta privada el humano puede ser **el mismo**, y ahí son **su** trabajo.

Es la única pérdida realmente propia del gesto: lo demás (categorías sembradas, grupos) o lo recrea la
app o sigue en la cuenta. El copy de la pantalla enumera «gastos, cuentas, presupuestos, categorías y tus
grupos» y no nombra esto.

También se van sin vuelta, y tampoco se dicen: `groupPrefs_*` (la cuenta de liquidación por grupo), los
overrides por grupo del bridge, y el desbloqueo de la beta de Grupos.

## Por dónde va

O el aviso cuenta lo que hay pendiente de subir —`CloudSessionSignOut.liveGroupsPendingCount` ya sabe
contarlo— o el borrado espera a que el outbox se vacíe, como hace el cierre de sesión. Lo primero es
barato; lo segundo es lo que hace el resto de la app en la misma situación.

## Cómo se prueba

- Unit: el contador ya existe y tiene tests.
- Device-QA: apuntar un gasto en avión, volver a cobertura solo después del borrado.
