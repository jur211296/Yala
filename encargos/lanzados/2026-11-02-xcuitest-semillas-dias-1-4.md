---
esfuerzo: medium
release: no
---
# XCUITest: cambiar de presupuesto los días 1–4 (semilla realista) y la fila de cuenta intermitente en GroupsSmoke

Cards: tablero-xcuitest-cambiar-de-presupuesto-en-la-na-04ek, tablero-xcuitest-test-groupexpenseaccountrowfoll-ctw7

## Contexto
04ek sale del PR #736: `AdaptiveNavigationUITests.test_switchingBudgets_showsTheNewBudgetsSpentAmount` (semilla `realista`) exige que «Comidas fuera» y «Fijos casa» gasten distinto, pero Vivienda no recibe gasto hasta el día 5: del 1 al 4 podrían salir los dos en S/ 0. El #736 resolvió lo mismo en `tarjeta-dos-lineas` con `seedDate(daysAgo:now:calendar:)` (tope al día 1 del mes). Ojo: `TEST_RUNNER_TZ` no llega a la app (`launchForUITest` no fija `launchEnvironment`).
ctw7 sale del #738: `tickets/backlog/groups-smoke-account-row-times-out-inside-the-suite.md`.

## Qué hacer
1. 04ek: que la semilla `realista` deje gasto distinto en los dos presupuestos cualquier día del mes; unit que barra los días y mutante.
2. ctw7: fechar el rojo con la nocturna y corregir el plazo o la espera si se confirma.

## Hecha cuando
Tests en verde, mutante del tope muerto, cards cerradas solas. Termina con /cerrar-total.

## Mini y simulador
Pipeline serial: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Nada solapado. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.

## Paso 0

Medido antes de decidir:

- **04ek.** En `realista` los seis presupuestos están en la sección «activos» los días 1–4 y se ordenan por nombre: fila 0 = «Comidas fuera», fila 2 = «Fijos casa». Vivienda no tiene ningún gasto fijo antes del día 5 (alquiler); solo un mantenimiento al azar (3 % por día). Comida sí puede salir a 0 un día 1 de fin de semana sin restaurante ni delivery. Riesgo real: los dos a S/ 0.
- **ctw7.** Nocturnas del 18-oct al 1-nov (15 corridas de `qa.yml` por `schedule`): `test_groupExpenseAccountRowFollowsThePayer` pasó las 15, a la primera iteración (~32 s), en runner frío. El único rojo es el local del 2-nov, que ya pasó 13/13 al repetir.

Decisiones (auto-contestadas, sin nadie delante):

1. **04ek: un gasto de vivienda en el mes en curso, solo en `realista` y solo los días 1–4**, fechado con el mismo tope del #736 (`DevSeedAccountLines.seedDate`, día 1 a medianoche como mínimo). Desde el día 5 no se siembra nada: el alquiler ya cubre el caso y así no se mueven las cifras de los demás tests ni de la ficha (`ficha`/`rendimiento` no lo llevan).
2. **Importe con céntimos (−184,50)**: todos los gastos de Comida del generador están redondeados a soles enteros, así que «Fijos casa» (184,50 + mantenimientos enteros) no puede igualar a «Comidas fuera» esos días. Es una garantía por construcción, no por suerte.
3. **Unit**: barre todos los días de 2026 (+ febrero 2028) a 00:30 y 23:30 — la fecha sale en el mes en curso, nunca en el futuro, y solo los días 1–4. Más una corrida de la semilla real que comprueba la premisa de los enteros. Mutante: quitar el tope de `seedDate`.
4. **ctw7: no se toca el plazo.** El rojo no se confirma en la nocturna; subir un plazo sin rojo que lo justifique esconde el siguiente. Ticket a `discarded` con la medida.
