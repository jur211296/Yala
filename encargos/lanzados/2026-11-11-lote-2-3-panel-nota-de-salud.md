Yala
# Decidido 9-nov 2.3 · Panel: la nota de salud con pocos datos
card: tablero-2-3-panel-la-nota-de-salud-con-pocos-dat-9z8z
toca: Yala/App/Views/Panel/, Yala/App/Logic/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 9 (A dos de tres + B, y propuesta abierta). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/30-panel/ficha.md. Hallazgo PN-2.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. La nota de salud no puntúa 99-100 con pocos datos ni ignora lo que va mal. Opción A (dos de tres partes) + B: sin nota hasta tener dos de tres partes, la tarjeta dice qué falta; una línea con lo que la nota no ve (presupuesto pasado, cuenta en rojo) y el mensaje deja de decir «¡Vas increíble!» con alertas. Además, esta sesión propone por escrito mejoras a la salud financiera (variables nuevas, cálculo, visibilidad) para que Jürgen las decida; no las apliques tú.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Las propuestas de mejora quedan en el PR o en una nota de la card, en espera de decisión. No las implementes en este lote.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (resueltas en autónomo, modo semi; discutibles en el PR)

0. **Base.** `origin/2.3`. `rev-list origin/2.3..origin/2.2` = 16: la cola de 2.2 tras el merge corto (Grupos, TestFlight 2.2 (9), docs). Ninguno toca la nota de salud ni el Panel salvo `GroupBridgeLeftoverLogic`/`InboxDraftDisplayCurrencyLogic` (Grupos). Se da por «casi 0» para este punto y se sigue.
1. **Vivo en 2.3.** `computeTotal` re-pondera con una sola parte (`FinancialScoreCalculator`), el hoja dice «¡Vas increíble!» con ≥ 90 sin mirar nada más. `git log origin/2.3..origin/2.2 -- <ficheros de la nota>` vacío: 2.2 no lo arregló.
2. **Dónde vive «dos de tres».** En el cálculo (`computeTotal`, `minimumPartsForTotal = 2`), no en la vista: la misma tarjeta sale en Panel y en Estadísticas › Resumen, y una cifra tiene una regla. Pesos, suelo y fórmula no cambian.
3. **Qué es «alerta».** Hoy, y solo si el período elegido incluye hoy: (a) un presupuesto activo cuyo período en curso ya se pasó del límite (`BudgetRemainingLogic.isOver`, lo gastado con `BudgetsViewModel.calculateSpending`, la cuenta de Planificación); (b) una cuenta con saldo negativo (saldo de la tarjeta del carrusel, `AccountBalanceCalculator`), sin tarjetas de crédito, líneas de tarjeta, cuentas de Grupos, archivadas ni excluidas de las estadísticas.
4. **Qué «no ve» la nota.** Las cuentas en negativo (la nota no mira saldos de cuenta) y los presupuestos pasados que aún no cuentan (creados a mitad de período: misma regla que el cálculo, `bucketIsValid`). Un presupuesto pasado que sí cuenta ya baja la nota y no se repite en la línea.
5. **Mensaje.** Con nota ≥ 90 y cualquier alerta, la hoja deja «¡Vas increíble!» por un titular propio. Sin nota con alguna parte con datos: «Todavía no hay nota» (antes decía «Empieza con tu primer registro» a quien ya registra).
6. **Solo gastos.** En el modo «Solo gastos» no hay saldos que valgan (no se apuntan ingresos): las cuentas en negativo no salen.
7. **Texto de «qué falta».** Nombra las dos partes que faltan con su nombre de la tarjeta; sin ninguna parte, la regla a secas. Sin `ListFormatter` (el idioma de la app no es siempre el del sistema).
8. **Tests.** Unit del cálculo y de las alertas (rojo sin el arreglo: el test viejo `total_onlyRhythmPresent` fijaba el 100 de una parte y pasa a pedir `nil`). XCUITest con la semilla `cuenta-con-movimientos` (tres registros y «Efectivo QA» en −58): antes 100, después «—», qué falta y la línea de lo que no ve.
9. **Propuestas de mejora de la nota.** Por escrito en el PR y en la nota de la card; no se implementan.
