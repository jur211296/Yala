---
updated: 2026-09-02
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-02 (Lima)

**Rama** `2.1` · **HEAD** `8168987a` — *el rojo de `.thisWeek` era el test*.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión
Cerrado el **doble conteo del día 1**: una TX de día 1 a medianoche —alquiler, nómina— se contaba a
la vez en el período actual y en el anterior. Medido: contaminaba el informe **730/730 días**,
Estadísticas 28/730, la interanual 2/730; ahora **0/730**. Fix en la fuente (`PreviousPeriodHelper`,
sus dos ramas) más dos instancias a mano; el `-1s` de la rama de año va **condicionado** a que el
extremo sea medianoche. 3 mutantes en rojo. Antes: el rojo de `.thisWeek` y el trailer de commit.

## Abiertos
- **`welcome-fresh-start-alert-leaves-blank-screen`** (backlog, **high**) — «Es mi primera vez» +
  cancelar deja la app sin salida salvo matarla. Preexistente, **en producción**.
- **`scheduled-payment-once-labeled-monthly`** (backlog, low) — badge cosmético.
- **`undercount-dias-intervalos-cerrados`** (backlog, medium) — `dateComponents([.day])` trunca, así
  que todo intervalo que cierre en 23:59:59 cuenta un día de menos: medido, falla **730/730** en
  `.lastMonth`. Son denominadores de promedios. Normalizado sólo donde este fix lo habría empeorado.
- **`AUDIT-appstore-guidelines.md`** — 3 hallazgos de riesgo de rechazo (OpenAI). De Lola.

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Siguiente
El **undercount de días** (ticket arriba): ~6 sitios cuentan con `dateComponents([.day])` y falta
trazar cuáles reciben un intervalo con `-1s`. Del Panel quedan dos: «Últimos registros» se dice dos
veces y bajar los nombres de fila a 15 tocaría Estadísticas. **Zanjados hoy:** el trailer
`Co-Authored-By` (no va; los 11 que lo llevan no se reescriben), el rojo de `.thisWeek` y el doble
conteo. **Ojo al método:** hoy tres coordenadas citadas sin re-medir resultaron falsas.

## Bloqueo
Ninguno.
