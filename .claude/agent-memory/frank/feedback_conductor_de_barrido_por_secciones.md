---
name: conductor-de-barrido-por-secciones
description: Un barrido de pantallas cabe en 30 min con un conductor XCUITest por secciones y relanzado sin reset; el SE con texto máximo y el Duo cerrado esconden pestañas al conductor.
metadata:
  type: feedback
---

Barrido de la 2.3 tras Flujo de caja (19-nov-2026, Max): un conductor XCUITest temporal con una sección por pantalla,
cada una con un relanzamiento SIN `-uitest-reset` (la semilla no se repite) y variantes por `TEST_RUNNER_CAPTURA_VARIANTES`,
recorrió 17 Pro claro+oscuro (10 min), SE texto máximo (10), iPad (3,5) y Duo cerrado (2): justo los 30 min del tope.
Las cifras se apuntan como `label` del elemento en un `pasos.txt` junto a las capturas, y el widget se calcula desde
`widget_data_cache` del plist del App Group (script en `~/Claude/entregas/2026-11-19-barrido-qa-2-3-post-flujo/scripts/`).

- **SE con texto al máximo**: la pastilla «Pagos planificados» queda fuera de pantalla (x>375) y `selectTab`/`tap` fallan
  duro y cortan el test. **Duo cerrado**: la barra va en vertical y «Más» no existe sin desplegarla. Ordena las secciones
  que más importan primero, o haz que la sección salte en vez de afirmar.
- **El primer `build-for-testing` genérico** (`generic/platform=iOS Simulator`) compila x86_64 también y se colgó 10 min
  sin hijos vivos; con `-destination id=<sim>` acabó en 3.

**Why:** Jürgen aceptó (opción A) cortar al tope y anotar lo no recorrido; el orden de secciones decide qué se queda fuera.
**How to apply:** próximo barrido de pantallas: secciones prioritarias primero, SE y Duo con sus propias listas cortas.
Relacionado: [[capturas-con-conductor-xcuitest]], [[barrido-filtro-doble-minimo-qa]].
