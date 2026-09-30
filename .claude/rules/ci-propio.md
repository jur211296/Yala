---
description: El CI propio en la Mini (runner `mini-ci`, usuario `ci`) — los candados de máquina, por qué `ci` es un usuario aparte y qué se sabe de la caída del 2026-09-30. Se carga al tocar el workflow en sombra o los scripts del runner.
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
| `antes` | Disco libre ≥ 15 GB, RAM libre ≥ 35 %, **cero** `xcodebuild` y **cero** simuladores arrancados, sean de quien sean | Espera hasta 20 min. Si sigue igual, el job sale en rojo sin haber tocado nada |
| `vigia` (de fondo) | RAM libre ≥ 12 % y disco ≥ 10 GB, cada 30 s. Cada 5 min deja una foto en el log | Para los `xcodebuild` **de `ci`**, con `pkill -u`, y el job sale en rojo aunque los tests sean advisory |
| `despues` | Se queda con los 3 últimos xcresult. Si el DerivedData pasa de 20 GB, lo borra | — |

Lo que **no** se hace, nunca, desde el CI ni desde una sesión que lo esté montando:

- Tocar procesos o simuladores de otro usuario. Ni `simctl shutdown all` ni `erase all` desde
  `jur`, ni `killall Simulator`, ni `pkill xcodebuild` sin `-u ci`.
- Lanzar una corrida en sombra con Cola A viva, con otra sesión compilando o con el disco por
  debajo de 15 GB. El candado `antes` ya lo impide. Saltárselo a mano es justo lo que no se hace.
- Correr la suite completa en la Mini solo para validar un cambio del instalador o del workflow.
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

## La caída del 2026-09-30: qué se midió y qué no

A las 13:09 (Lima) cayeron todas las sesiones de Claude de la Mini. En ese momento corría en `ci`
la suite unitaria entera: la 4.ª corrida en sombra, de 12:41 a 13:12. La Mini no se reinició.

**Medido:**

- No hay ningún `JetsamEvent` de ese día.
- El log del kernel no registra ningún evento de memoria (`memorystatus`, `jetsam`, compresor)
  entre 13:08 y 13:10.
- A las 13:09:03 **Grok Bot se cerró** (`exit(0)`, `QUITTING`) y se relanzó a las 13:09:18. La
  sesión caída anotó su última tarea como `killed` a las 13:09:08.
- El servidor tmux que sigue vivo hoy lo arrancó el relanzamiento de las 13:30.
- Un `log` dentro de un simulador escribió 2 GB en 17 min, de 12:55 a 13:12.

**Inferido, sin probar:** el servidor tmux de las sesiones cayó junto con Grok Bot, no por falta de
memoria. Si fue así, el CI coincidió con la caída pero no la causó. Probarlo pide root
(`launchctl procinfo` sobre el servidor tmux) y es terreno de casa (`lanzar-sesion`), no de este
repo. Los candados de arriba se mantienen igual: la carga del CI sobre 16 GB es real aunque esta
vez no fuera la causa.
