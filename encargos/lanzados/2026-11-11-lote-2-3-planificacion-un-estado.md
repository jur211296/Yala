Yala
# Decidido 9-nov 2.3 · Planificación: un solo estado y el cupo del día en tono neutro
card: tablero-2-3-planificacion-un-solo-estado-y-el-cu-vogf
toca: Yala/App/Views/Planning/, Yala/App/Logic/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 23 (S1 + cupo diario como guía neutra). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/34-planificacion/ficha.md. Hallazgo 34 P1. El deshacer de un pago (decisión 24) ya va en el lote necesario 04, ya encolado: no lo toques aquí.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Al 90 % deja de decir «Te quedan», «En el límite» y «Hoy te pasaste» a la vez. Un estado, una palabra, un color, mismos umbrales en barra, palabra, sección e historial (80 % «En el límite», 100 % exacto «Llegaste al límite», >100 % «Te pasaste»). El cálculo del cupo ya es el pedido (medido en DailyAllowanceLogic); lo que cambia es el tono: línea neutra, sin rosa ni alerta, tipo «Quedan 5 días y S/ 400: unos S/ 80 al día. Hoy llevas S/ 120, S/ 40 más que eso». Pasarse un día es válido. Con el mes agotado la línea no sale.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- No cambies la fórmula del cupo diario; solo el tono y la unificación de estados.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo semi): las recomendaciones se dan por buenas. Se discuten en el PR. La opción
> (S1 + cupo neutro) la eligió Jürgen el 9-nov; aquí solo se deciden los detalles que la decisión no fija.

**D0 · ¿2.3 tiene lo de 2.2?** → Sí, para este lote. Faltan 16 commits de 2.2 (Grupos, TestFlight y documentación) y
ninguno toca `Views/Planning`, la barra, la palabra, el cupo ni `BudgetsViewModel`. Por qué: el merge corto del 10-nov
está dentro; lo que falta es posterior y de otra zona. Alternativa descartada: parar con BLOQUEANTE, que frenaría por
algo que no toca este punto.

**D1 · Fuente única del estado.** → `BudgetStatusCounter.classify` pasa a cuatro estados (`onTrack` < 80 %, `atLimit`
80–99 %, `reachedLimit` 100 % exacto, `overLimit` > 100 %), y «exacto» y «pasado» los decide `BudgetRemainingLogic.remaining`
(medio céntimo de holgura), la misma regla de «Te quedan / Te pasaste por». Por qué: hoy la sección y la barra rosa usan
`>=` y la cifra `>`; al 100 % exacto la fila salía en «Excedidos» con «Te quedan S/ 0.00» y el ánimo de pasarse.

**D2 · 100 % exacto.** → «Llegaste al límite», en naranja (el color de aviso, no el rosa), la fila en «Activos», sin
la frase de ánimo y con «Te quedan S/ 0.00». Por qué: la decisión dice que pasarse empieza por encima del 100 %; el
rosa queda para «Te pasaste». Alternativa descartada: rosa, que volvería a decir «te pasaste» con el color.

**D3 · La palabra.** → Debajo de la barra, en fila y detalle, una palabra por estado: «En el límite» y «Llegaste al
límite» en naranja, «Te pasaste» en rosa; por debajo del 80 %, nada. VoiceOver la dice en la fila. Por qué: «un estado,
una palabra, un color» y la maqueta S1 la enseña también al pasarse.

**D4 · Sección e historial.** → «Excedidos» solo con «Te pasaste» (`BudgetsViewModel.calculateBudgetStatus` y el gemelo
del Panel, `PanelViewModel.getBudgetStatus`, que pinta la misma barra). Las barras del historial de Gráficas toman el
color del mismo estado: neutro, naranja (80–100 %) o rosa (> 100 %). La barra simplificada de Estadísticas › Observaciones
deja de ponerse rosa al 100 % exacto. Por qué: mismos umbrales en todas las piezas. Fuera: el contexto de Yala IA
(`FullFinancialContextBuilder`, 75 % y `>=`), que no se pinta; va a «Encontrado».

**D5 · Texto del cupo del día.** → Línea neutra en gris, sin rosa ni icono de alerta, con la fórmula de siempre:
- sin gasto hoy: «Quedan 5 días y S/ 400.00: unos S/ 80.00 al día.»
- con gasto hoy: «Empezaste el día con S/ 400.00 para 5 días: unos S/ 80.00 al día. Hoy llevas S/ 120.00, S/ 40.00 más que eso.» (o «Hoy llevas S/ 30.00.» si no lo supera)
- último día: «Último día: quedan S/ 50.00.» / «Empezaste el último día con S/ 50.00. Hoy llevas S/ 30.00.»
Por qué: los S/ 400 de la fórmula son lo que quedaba al EMPEZAR el día; con «Quedan S/ 400» y «Te quedan S/ 280» en la
misma tarjeta, las dos cifras no cuadrarían (el problema P1). Alternativa descartada: copiar el ejemplo literal.
Con el mes agotado la línea no sale (ya era así).

**D6 · Icono y alto de la línea.** → Se queda el sol en el color del tema, siempre; la línea puede ocupar varias líneas
(antes una, encogida al 70 %), también en la fila del Panel que comparte la pieza. Por qué: la frase nueva no cabe en
una línea y encogida no se lee.

**D7 · Contadores.** → `reachedLimit` cuenta en «en el límite», no en «superados». Por qué: no se pasó.

**D8 · Semilla de QA.** → `-uitest-seed-budget-states` (solo DEBUG): cuatro presupuestos de 1.000 filtrados por su
etiqueta, al 30,5 %, 90 % (con el cupo de hoy superado), 100 % y 118 %. Por qué: capturas antes/después y el XCUITest
necesitan cifras exactas el día que sea; la semilla «realista» varía con la fecha.

**D9 · Límite 0 sin gasto.** → Pasa de «Excedidos» a «Activos» (antes `0 >= 0`). Por qué: misma regla; el editor no deja
guardar un límite 0, así que es un borde sin usuarios.

**D10 · Textos viejos del cupo.** → `budgets.daily.canSpend` y `budgets.daily.overToday` se retiran de los 16 idiomas si
nada más los usa. Por qué: sin usos, la batería de paridad los arrastraría como basura.
