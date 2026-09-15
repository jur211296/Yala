---
name: 403-infra-no-es-veredicto-de-cuenta
description: PR #154 — el canal de Grupos separa el 403 del kill del de infraestructura; el sello que quedó sin productor se retiró el 15-sep y el cierre .cloud sigue colapsando en .permanent (ticket high para Jürgen).
metadata:
  type: project
---

**PR #154 (mergeado 2026-09-14).** El canal de sync de Grupos ya no trata un 403 de infraestructura
—proxy, WAF, página de error del edge— como un veredicto sobre la cuenta: es `.transient`, con
backoff y con breadcrumb propio (`forbiddenNotKill edge=push|pull`). El kill (`yala_groups_disabled`)
sigue como lo dejó #152.

**Why:** el canal está **encendido en producción** (`GROUPS_BACKEND_ROLLOUT_PERCENT = 100`), así que
era un bug vivo, no dormido. Antes, ese 403 sellaba el canal el resto de la vida del proceso y la
persona veía «revisa tu conexión» al cerrar sesión o soltar su cuenta de grupos.

**How to apply:** lo que hay que recordar antes de tocar esta zona otra vez —

- **Lo que quedó abierto y es de Jürgen:** en el cierre de sesión de una cuenta `.cloud`,
  `CloudSessionSignOut` colapsa en `.permanent` **todo** veredicto de grupos que no sea
  `.channelPaused`, así que ahí el aviso sigue siendo el equivocado. Tres opciones planteadas en
  `cloud-signout-collapses-every-groups-transient-into-permanent` (`high`). **No lo toques sin su
  respuesta:** cambiar ese ternario mueve también la red caída y los 5xx.
- **El sello `stoppedUntilRelaunch` del canal de Grupos ya no existe**: quedó sin productor con este PR
  y se retiró el 2026-09-15 (decisión 4A de Jürgen, `groups-channel-seal-has-no-reachable-producer`).
  Toda parada del loop es re-arrancable. Si un caso nuevo pide parar el canal hasta relanzar, se escribe
  de cero y con su productor medido en el gateway.
- **El sello solo existía en el modo loop-propio.** Con el runtime personal cadenciando, el ciclo de
  grupos va de piggyback y su outcome se descarta: la frase «apagaba el canal el resto de la vida del
  proceso» valía para la sesión solo-grupos, no para toda la población.
- **Sin device-QA y no es pereza:** provocar un 403 desde algo por delante del Worker no se puede ni
  en simulador ni en device sin un seam que hoy no existe. La cobertura es la suite unitaria.
- Ver también [[el-test-viejo-cuelga-no-falla]] y
  [[mi-arreglo-deja-el-mecanismo-sin-productor]], las dos lecciones de método que dejó esta sesión.
