---
description: El CI propio en la Mini (runner `mini-ci`, usuario `ci`) — los candados de máquina, por qué `ci` es un usuario aparte y la caída del 2026-09-30 por CPU. Se carga al tocar el workflow en sombra o los scripts del runner.
paths:
  - ".github/workflows/ci-sombra.yml"
  - "qa/scripts/ci-runner/**"
---

# CI propio en la Mini

## La regla: una carga pesada a la vez, y el CI es el que cede

La Mini tiene 16 GB. En ella trabajan a la vez las sesiones de Claude de Jürgen, sus simuladores,
las colas y ahora el runner. Un `xcodebuild test` con su simulador es la carga más pesada de la
máquina, y dos a la vez no caben. Por eso el CI **espera y cede**. No se le da prioridad.

`qa/scripts/ci-runner/guardia.sh` lo hace cumplir desde dentro del workflow, así que no depende de
que nadie se acuerde:

| Fase | Qué comprueba | Si falla |
|---|---|---|
| `antes` | Disco libre ≥ 15 GB, RAM libre ≥ 35 %, carga de 1 min ≤ 10 (hay 10 núcleos), Time Machine parado, **cero** `xcodebuild` y **cero** simuladores arrancados, sean de quien sean | Espera hasta 20 min. Si sigue igual, el job sale en rojo sin haber tocado nada |
| `vigia` (de fondo, solo como `ci`) | Cada 30 s: pone a nice 10 todo lo de `ci` (simulador incluido); RAM libre ≥ 12 %, disco ≥ 10 GB y carga ≤ 24, que no se sostenga 2 min. Cada 5 min deja una foto en el log | Para los `xcodebuild` **de `ci`**, con `pkill -u`, y el job sale en rojo aunque los tests sean advisory |
| `despues` | Se queda con los 3 últimos xcresult. Si el DerivedData pasa de 20 GB, lo borra | — |

Lo que **no** se hace, nunca, desde el CI ni desde una sesión que lo esté montando:

- Tocar procesos o simuladores de otro usuario. Ni `simctl shutdown all` ni `erase all` desde
  `jur`, ni `killall Simulator`, ni `pkill xcodebuild` sin `-u ci`.
- Lanzar una corrida en sombra con Cola A viva, con otra sesión compilando o con el disco por
  debajo de 15 GB. El candado `antes` ya lo impide. Saltárselo a mano es justo lo que no se hace.
- Correr la suite completa en la Mini solo para validar un cambio del instalador o del workflow.
- Correr `guardia.sh vigia` sin `GUARDIA_SECO=1` con un usuario que no sea `ci`. Baja la prioridad
  de **todo** lo de ese usuario, y deshacerlo pide root. El script ya se niega a hacerlo, porque
  pasó el 2026-09-30: 420 procesos de `jur` quedaron a nice 20. Y `renice -n` en macOS es un
  **incremento**: en un bucle suma en cada vuelta. La prioridad se fija en absoluto, `renice 10`.
  Para eso basta el banco en seco: `GUARDIA_SECO=1` y umbrales forzados por variable de entorno.

Si subes un umbral, mide antes cuánto marca la Mini en reposo con `guardia.sh foto`. El
2026-09-30 marcaba un 61 % de RAM libre con cuatro sesiones de Claude abiertas.

## Por qué `ci` es un usuario aparte, y no Jürgen

Se preguntó el 2026-09-30 si este usuario era demasiada carga. Medido: en reposo, la sesión de
`ci` ocupa ~1–1,5 GB (312 procesos suman 2,4 GB de RSS, pero esa suma cuenta varias veces la
memoria compartida). El runner ocupa 30 MB. Lo que pesa es la suite de tests, y pesa lo mismo con
cualquier usuario.

A cambio, separarlo da dos cosas que no se negocian:

- **Seguridad.** Un workflow que corre como `jur` alcanza su llavero, sus claves SSH y
  `~/Secrets`.
- **Aislamiento.** `ci` tiene su propio juego de simuladores y su propio DerivedData, y no toca
  los de Jürgen ni los de las colas.

Tiene que ser un **LaunchAgent con sesión gráfica** y no un daemon. Sin sesión Aqua, los tests
unitarios iban ~1.000× más lentos. La medida está en la cabecera de `instalar.sh`.

La sesión de `ci` arranca servicios que el runner no usa: análisis de fotos, Siri, los ítems de
inicio globales como Jump Desktop… Recortarlos es barato. Además,
`com.apple.accessibility.heard` se relanzaba cada segundo en esa sesión, medido el 2026-09-30.

## La caída del 2026-09-30: fue CPU, no memoria

Entre 12:55 y 13:09 (Lima) la Mini se ahogó y cayeron todas las sesiones de Claude, sin reinicio.
Coincidieron tres cargas: la suite unitaria en el simulador de `ci` (la 4.ª corrida en sombra, de
12:41 a 13:12), Time Machine y Spotlight.

**Medido en la Mini:**

- Time Machine (`backupd`) activo de 12:40 a 13:13, con un informe de CPU excesiva a las 12:30.
- Spotlight (`spotlightknowledged`) con informes de CPU a las 12:53 y a las 13:16.
- Ningún `JetsamEvent`, y ningún evento de memoria del kernel entre 13:08 y 13:10. Por eso
  no fue OOM.
- Un `log` dentro de un simulador escribió 2 GB en 17 min, de 12:55 a 13:12.

**Según Grok, que lo vio en vivo:** la carga llegó a ~37, y eso ahogó el bridge de Grok Bot, que se
reinició a las 13:09. **Los tmux no colgaban de Grok Bot**, así que su reinicio no se llevó las
sesiones. Una primera lectura de esta sesión lo suponía, y era falso.

La lección: el candado que falta no es de memoria, es de **CPU y de lo que la Mini hace sola**
(Time Machine, Spotlight). De ahí la carga, Time Machine y el `renice` del vigía.
