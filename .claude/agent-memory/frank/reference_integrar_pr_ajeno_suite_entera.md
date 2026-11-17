---
name: integrar-pr-ajeno-suite-entera
description: Para validar el merge de 2.3 en la rama de otro PR, YalaTests entero (~7 min de prueba en la Mini) sale más barato que elegir suites; un rojo de una vez se repite antes de creerlo.
metadata:
  type: reference
---

Al traer 2.3 a la rama de un PR ajeno con conflictos (textos, TICKETS.md, coverage-index), el gate práctico fue: `YalaTests` entero con el esquema Yala (14.589 casos, ~7 min de prueba más la compilación), build de Yala Dev y `gate-ci-checks.sh`. Elegir suites con `suites-de-fichero.py` desde zsh falla (sin word-splitting) y con 20 ficheros tocados no compensa.

Medido el 17-nov: una corrida dio 2 rojos de «última cuenta» (App Group compartido) y la siguiente, sobre el mismo árbol, 0 → ticket `unit-tests-last-used-account-leaks-between-suites`. Tras la suite unitaria larga, el siguiente XCUITest murió con «AX loaded»: reiniciar el simulador (ver [[runner-ax-timeout-tras-suite-larga]]).
