---
name: only-testing-filtra-por-tipo-no-por-fichero
description: Creí haber verificado cinco suites que NUNCA se ejecutaron — usé nombres de fichero y -only-testing filtra por TIPO; un fichero de este repo declara hasta 4 @Suite. El conteo pedido vs. ejecutado es la única red.
metadata:
  type: feedback
---

**Cuenta SIEMPRE las suites que pediste contra las que reporta `Test run with N tests in M suites`.
Si M < lo pedido, no verificaste lo que crees.**

**Why:** el 2026-09-14, en el gate del cierre por cambio de Apple ID, pedí 12 suites y corrieron **7**.
Las cinco que faltaban las había escrito con el nombre del **fichero** (`PersonalMountWitnessTests`,
`RelaunchNetLogicTests`, `NeutralMountRelaunchZeroTests`, `PersonalSwapReleaseTests`,
`GroupsOnlyNeutralMountTests`) y **ninguno existe como tipo**: cada uno de esos ficheros declara
**cuatro** `struct` distintos. `-only-testing` filtra por TIPO, así que un nombre inexistente
**desaparece sin ruido** y la corrida sale `TEST SUCCEEDED`.

Lo peor no fue el hueco: fue que en **dos corridas anteriores** di por verificada
`PersonalMountWitnessTests`, y dentro de ese fichero vive `PersonalMountWitnessWiringTests`, el
source-scan de `checkForICloudMismatch` — **la función que yo acababa de modificar**. Creía tener una
red sobre mi propio cambio y no la tenía. Al correrlas con los nombres de tipo: 21/21 verde, pero eso
lo supe media hora después.

La rule `.claude/rules/testing.md` ya lo dice (`L155`) y aun así lo cometí, porque el nombre del
fichero y el del tipo **coinciden en la mayoría de los casos** — coinciden justo hasta que el fichero
crece y alguien parte la suite en cuatro.

**How to apply:**

- Antes de pasar una lista a `-only-testing`, resuélvela:
  `grep -n "^struct \|^final class " <fichero>`. No la deduzcas del nombre del fichero.
- Después de correr, **compara el número**. `Test run with N tests in M suites` es la línea; con
  `-quiet` no sale, y por eso el gate prohíbe ese flag.
- La segunda (tercera, cuarta) suite de un fichero suele ser **la de source-scan del cableado** — la
  que más te interesa cuando tocas producción, y la que más fácil se pierde.
- Y cuando el cambio toca un choke-point (`SwiftDataConfiguration`, `ContentView`), sale más barato
  correr `YalaTests` entero que elegir bien... **si la máquina aguanta**: ese mismo día la corrida
  completa la mató el OOM del sistema a los 10 minutos, sin veredicto. Entonces se hace por lotes, y
  entonces vuelve a hacer falta esta regla.

Relacionado: [[el-barrido-qa-rinde-por-lotes]] · [[gate-paso3-no-detecta-cero-casos]] ·
[[mis-mediciones-fallan-por-el-filtro]]
