# Arreglar el XCUITest del presupuesto de la tarjeta que sale al 0 % los días 1 a 3 de cada mes

Card: tablero-xcuitest-el-presupuesto-de-la-tarjeta-sa-xn78

## Contexto
Medido el 2026-11-01 en el gate de otra sesión: `AccountCardPickersUITests.test_budgetOnTheCard_countsTheLineExpense` falla con «0 por ciento gastado», también con el binario de la base (sin cambios ajenos). Causa encontrada: la semilla `DevSeedAccountLines` (perfil `tarjeta-dos-lineas`) fecha «Supermercado QA» y «Hotel QA» 2 y 3 días atrás; los días 1 a 3 del mes caen en el mes anterior y el presupuesto del mes en curso queda en 0. Es la trampa de `testing.md`: un caso cuyo escenario lo pone la semilla del día sale verde unos días y rojo otros. Trabaja sobre la rama 2.2.

## Qué se pide
Que esos gastos de la semilla caigan siempre dentro del mes en curso (o que el test cree su propio gasto), sin romper los demás tests que usan ese perfil. Busca si otros perfiles de la semilla tienen la misma trampa y anótalo como hallazgo (card en el tablero si es real), sin arreglarlos aquí salvo que sea el mismo cambio trivial.

## Qué NO hay que tocar
Lógica de producción de presupuestos; nada de Grupos (hay una serie Grupos B en curso en otras ramas).

## Cómo se sabe que está bien
El caso pasa con el reloj del simulador en el día 1 de un mes (TEST_RUNNER_TZ o fecha fija) y en un día cualquiera; los demás tests del perfil siguen verdes. Al terminar, la card pasa a done (no hay nada que probar en el iPhone).

## Mini y CI
Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagar y limpiar ese simulador. Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques los de otra sesión viva.
La sesión arranca ya sobre `origin/2.2`. Justo antes del gate, mira si el PR #735 (Grupos B card 1) sigue en CI; si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si 2.2 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

Termina con `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Se arregla la semilla o el test crea su gasto?** → La semilla: «hace N días» no baja del día 1 del mes en curso.
Por qué: otros casos del perfil (filtro del Panel, informe, flujo de caja) leen los mismos movimientos del mes y heredan el mismo rojo de días 1-3; arreglar el test solo dejaría esos vivos. Alternativa descartada: gasto propio en el test, más gestos y no cubre a los hermanos.

**D2 · ¿Solo «Supermercado QA» y «Hotel QA» o los cinco movimientos?** → Los cinco, por el mismo `day(_:)`.
Por qué: es un único helper y la intención del perfil es «las cifras del Panel son las de aquí»; que el sueldo o el freelance se escapen al mes anterior es la misma trampa. Alternativa descartada: clamp solo en los dos gastos, deja la mitad del escenario dependiendo del día.

**D3 · ¿Dónde cae lo que cruzaría?** → El día 1 a medianoche (inicio del mes).
Por qué: está dentro del mes en curso (`DateInterval` cerrado por el inicio) y nunca es futuro. Alternativa descartada: «hoy a otra hora», que puede quedar en el futuro y salir como movimiento programado.

**D4 · ¿Cómo se prueba sin tocar el reloj de la Mac?** → Función pura `seedDate(daysAgo:now:calendar:)` con unit test que barre 730 momentos de 2026 (00:30 y 23:30 de cada día) más febrero de 2028: todo cae en el mes de `now` y nunca después; y lejos del borde la fecha es exactamente «hace N días». El XCUITest se corre en el día 1 real (la sesión arrancó el domingo 1-nov a las 20:15 de Lima), con la semilla vieja (mutante: rojo, «0 por ciento gastado») y con la nueva.
Por qué: `TEST_RUNNER_TZ` llega al runner, pero `launchForUITest` no lo pasa a la app (no hay `launchEnvironment`), así que no mueve el día que ve la app; los días 4 a 31 la semilla no cambia (lo fija el caso de mitad de mes). Alternativa descartada: seam de reloj en la app, que cambia producción y el encargo lo prohíbe.

**D5 · ¿Esperar al PR #735?** → No. Un solo fetch + rebase antes del build, y otro solo si hace falta antes del PR.
Por qué: la regla de toda sesión lanzada declara obsoleta cualquier espera de CI ajeno, y el encargo no tiene `depende:`.

**D6 · ¿Otros perfiles con la misma trampa?** → Se barren y se anotan como hallazgo con card si es real; no se arreglan aquí salvo que sea este mismo cambio trivial.

**D7 · El gate tras traer #735 sacó un rojo intermitente en `AccountCardReportsUITests.test_cashFlow_byCard_hidesTheLinePage_andByLineShowsIt` («Por línea» no tiene página para la línea). ¿Se arregla aquí?** → Sí, solo el gesto: el arrastre del carrusel pasa por la fila del título de la página en vez de por las barras.
Por qué: es un test del mismo perfil y el criterio pide que sigan verdes. El vídeo del rojo enseña 4 páginas y el caso parado en la 3.ª: la página existe y la gráfica se quedó el arrastre. Aislado, 1 de 3 rojo; con el cambio, 5 de 5. Alternativa descartada: Lista Negra, que deja vivo un rojo que se arregla en una línea.
