---
updated: 2026-09-02
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-02 (Lima)

**Rama** `2.1` · **HEAD** `aa5c6034` — *el board dejó de mentir*.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión
Saneado el board: de ocho tickets dados por arreglados, **siete estaban vivos** y salieron cuatro
defectos sin escribir. 87 tickets, índice cuadrado. Y arreglado el **calendario de Registros**, que
clasificaba el gasto por signo mientras el resumen de su misma pantalla usaba la categoría —
verificado por mutación (**600 → 300**), 12/12 verde, ahora en `qa/`.

## Abiertos
- **`ci-verde-con-la-suite-en-rojo`** (**high**) — CI verde con 8 tests en rojo. **No son tres
  líneas a borrar**: los `continue-on-error` tapan un crash de SwiftData del runner. Empieza por él.
- **`welcome-fresh-start-alert-leaves-blank-screen`** (**high**) — sin salida salvo matar la app.
  **En producción.** Arranca con simulador: su evidencia no cuadra con lo medido.
- **`invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo`** (**high**) — al recién instalado le
  falla el enlace de invitación sin que nada esté caído.
- **`aviso-de-nuevo-miembro-no-llega-hasta-abrir-la-app`** (**high**).
- **`canarios-y-breadcrumbs-sin-emisor`** (medium) — **19 señales sin emisor**, dos usadas como
  criterio «debe estar a 0»: lo está por construcción.
- **`undercount-dias-intervalos-cerrados`** · **`appstorage-onboarding-…`** (medium) ·
  **`scheduled-payment-once-labeled-monthly`** (low) · `InboxView:907` clasifica por signo con la
  categoría al lado (cosmético, sin ticket) · **`AUDIT-appstore-guidelines.md`**, de Lola.

## Te esperan a ti (no es código)
Cinco decisiones bloquean **8 tickets en `in-progress`**, parados desde el 6 y el 12–13 de agosto:
prefs que suben y no bajan · la puerta de Grupos y la señal de restauración · si el servidor puede
decir «te rechazaron» · qué se ofrece en un móvil prestado · cuándo se borran las pantallas muertas.
Detalle en cada ticket. **`secondary-groups-off-wipes-owner` ya no está bloqueado**: su dependencia
está hecha.

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Siguiente
Drenar `qa/` (12 tickets; `invite-backend-stale-config` y `storekit-appgroup-siri-pro-gate` ya
tienen receta de simulador escrita). O el **undercount de días**: ~7 sitios cuentan con
`dateComponents([.day])` sobre un intervalo y falta trazar cuáles reciben el `-1s`.
**Ojo al método:** esta sesión, 59 coordenadas citadas resultaron falsas al re-medirlas.

## Bloqueo
Ninguno técnico. Los 8 de `in-progress` esperan las cinco decisiones de arriba.
