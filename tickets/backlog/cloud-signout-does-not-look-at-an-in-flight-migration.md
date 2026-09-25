---
id: cloud-signout-does-not-look-at-an-in-flight-migration
status: backlog
priority: low
area: "modo-nube, cierre de sesión, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate` (2026-09-25)"
---

# Cerrar sesión no mira si hay un cambio a la nube (o de vuelta) en marcha

## El problema, en lenguaje de usuario

Si pulsas «Cerrar sesión» mientras Yala está a mitad de mover tus datos (a la nube o de vuelta a iCloud), el cierre sigue
adelante y arma el borrado aunque el proceso de la migración siga trabajando. INFERIDO: no se ha reproducido.

## Medido (2026-09-25)

- `CloudSessionSignOut.signOut` elige el camino por `storageMode` y la sesión; no lee la fase de la migración.
- Desde `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate` el push-all del cierre no corre ciclo con una fase
  transitoria: sin pendientes sigue al borrado. No lo nació ese cambio (antes corría un ciclo encima del runner), pero ya no
  hay ciclo que acompañe.
- Sin medir: si la pantalla de Perfil deja llegar a «Cerrar sesión» con una fase transitoria en vuelo.

## Criterios de aceptación

- [ ] Medido si el cierre es alcanzable con una fase transitoria en vuelo; si lo es, decidido qué hace (esperar, bloquear o
  cancelar la migración primero).
