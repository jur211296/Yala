---
name: barrido-cubre-toda-la-version
description: El barrido previo a un TestFlight cubre todo lo de la versión que no está en done (cards in qa, tickets/qa y bugs del backlog), no solo lo nuevo desde la build anterior; tope de 2 h de pruebas.
metadata:
  type: feedback
---

El barrido de QA antes de una build cubre **toda la versión que no está en «done»**: las cards en «in qa», los
tickets de `tickets/qa/` y, de las cards de bugs del backlog, si siguen pasando (si no, se propone cerrarlas). Las
funciones del backlog que no están construidas no se prueban. Tope de pruebas: **2 h**, no los 30 min del pie.

**Why:** Jürgen, 27-nov-2026, barrido antes de la build 12 de 2.3: «quiero que cubra todo 2.3 que no esté en done,
no solo lo nuevo, para asegurar que quede fino». El encargo solo pedía lo nuevo desde la build 11.

**How to apply:** al arrancar un barrido, mide `tablero listar --proyecto Yala --version <v>` por columna y cruza con
`tickets/qa/`. Lo que ya fijan las pruebas automáticas no se repite en el iPhone. Ver [[barrido-filtro-doble-minimo-qa]].
