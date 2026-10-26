---
id: check-test-isolation-counts-comments
status: backlog
priority: low
area: "qa, ci"
created: 2026-10-26
updated: 2026-10-26
source: "sesión S6 (segmento-ver-solo-ocultar), 2026-10-26: #634 atascado toda la noche en cola de auto-merge"
---

# El check de aislamiento de tests cuenta los comentarios

## Qué pasa

`qa/check-test-isolation.sh` busca `makeTestContext(` con `grep -rl` en todo el fichero, comentarios incluidos. Un fichero
de tests que solo NOMBRA la función en un comentario y no es `.serialized` hace caer el job `coverage-index`, que el
ruleset de `2.2` exige.

## Por qué importa

El PR #634 quedó en cola de auto-merge desde las 06:02 del 2026-10-26 sin entrar: el único motivo era una línea de
cabecera de `CombinedEntityFilterTests.swift` que decía «porque pide `makeTestContext()`». Nadie lo vio hasta que la
sesión siguiente lo midió. Se arregló cambiando el comentario, no el check.

## Arreglo propuesto

Que el check ignore las líneas que empiezan por `//` (y `///`) antes de buscar la llamada, con un caso de prueba en el
propio script. Barato; no cambia qué ficheros tienen que ser `.serialized`.

## Hecha cuando

Un fichero que solo menciona `makeTestContext()` en comentarios pasa el check, y uno que la llama sin `.serialized` sigue
cayendo.
