---
id: 2026-11-25-analisis-tandas-ui-rojo-espera-ci
status: backlog
priority: high
area: "ci, qa, proceso"
created: 2026-11-25
updated: 2026-11-25
source: "Pregunta de Jürgen del 25-nov a las 6:20 (Lima): por qué siguen las tandas de UI en rojo y si esperar el CI (~45 min por sesión) mejoró algo frente al auto-merge anterior"
---

# Análisis: tandas de UI en rojo y si esperar el CI mejoró algo

Jürgen decide con este análisis si se vuelve al auto-merge sin esperar. Es solo análisis: no cambia flujo,
workflows ni código.

## Respuesta

- **Desde cuándo se espera:** 19-nov-2026 a las 13:12 (Lima), decisión 125 de casa. Antes, desde el 30-sep
  (decisión 54 de casa), la sesión dejaba el PR en cola de auto-merge y cerraba.
- **Las tandas de UI no corren en los PR** desde el 6-sep: solo en la nocturna (comentario del job `ui` del
  workflow de QA). La espera del cierre es por build + unit + índice de cobertura.
- **Costo medido:** 95 esperas reales en las dos máquinas, 601 min de sesión al día, unas 70 h por semana.
  70 de 74 esperas de PR con código terminaron en «tope» (45 min) sin ver el merge: el CI de un PR con código
  tarda una mediana de 67 min.
- **Beneficio medido:** la sesión rebasó 9 conflictos y arregló 1 CI rojo propio en 5,7 días. La calidad no
  cambió: los checks requeridos ya frenaban un rojo antes del cambio. Reverts y hotfix: 0 y 0. 2.3 en rojo
  tras un merge: 2 antes y 2 después. Bugs en TestFlight o barridos: no medible (un bug no dice qué PR lo trajo).
- **UI nocturna:** 27 noches, 273 tandas, 85 rojas: 28 por infraestructura ya arreglada, 29 con una prueba
  real o probable real y 28 solo por intermitentes. 48 pruebas distintas: 14 reales, 3 nuevas probables
  reales, 26 intermitentes y 5 cuelgues de 10 min.
- **Tandas 1, 4, 5, 7 y 13 del 24-nov:** reales o probables reales Límite de tarjeta, Hacer recurrente (2) y
  Quitar repetidos; intermitentes el cuelgue de Yala IA, cambiar subcategoría y el chip del año pasado.
- **Recomendación:** auto-merge con una espera corta (≤5 min, solo hasta saber si el PR choca) y un vigía que
  relance una sesión ante conflicto de código o rojo propio; en paralelo, sanear la UI nocturna.

## Entregables

- Artifact: https://claude.ai/artifact/VEcRutGkQQF6KEALVKTsAA
- Datos crudos y scripts: `docs/analisis/ci-ui-rojo-2026-11-25/`
- 10 cards en 2.3 del tablero, asignadas a Frank: Límite de tarjeta, Hacer recurrente, Quitar repetidos,
  cuelgues de 10 min, Restablecer del Panel, convertir a grupo, cambiar subcategoría, chip del año pasado,
  cuarentena para la UI y CI de PR de 67 min.
