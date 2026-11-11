Yala
# Decidido 9-nov 2.3 · Panel: el día 1, la gráfica de saldo y las cuentas en el iPad
card: tablero-2-3-panel-el-dia-1-del-mes-la-grafica-de-gjda
toca: Yala/App/Views/Panel/, Yala/App/ViewModels/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 10, 11 y 12. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/30-panel/ficha.md. Tres hallazgos del Panel (PN-3, PN-4, PN-5 solo D).

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. El día 1 del mes ya no opina con un solo día (nota 96, gráfica de un punto y −100 %). Opción E, umbral día 3: el período manda siempre; la app nunca lo cambia sola ni muestra otra ventana. Días 1 y 2: línea «Día N de 31 · Ver últimos 30 días · Ver <mes anterior>», y los atajos cambian el selector de verdad. Porcentajes ocultos hasta el día 3 (solo el monto). La gráfica se queda como está, con su punto suelto.
2. La gráfica de saldo dice contra qué compara (opción A + B): el chip lo nombra, el globo usa «S/» y «Promedio», el eje largo pone el año; inicio → hoy y su % debajo de la gráfica. El eje no arranca en cero; sí cabe un margen en los extremos. Palabras alineadas con la decisión 8 («Saldo»/«Tienes»).
3. Solo opción D de PN-5: en el iPad, las cuentas en cuadrícula junto a la cifra grande. El carrusel del iPhone, la marca «En negativo» y la salud al plegar no se tocan.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- No implementes el total del carrusel ni la marca «En negativo»: la decisión 12 eligió solo D.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo semi): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · ¿2.3 tiene lo de 2.2?** → Sí, para este lote. A 2.3 le faltan 16 commits de 2.2, todos posteriores al merge corto de 2.2 en 2.3 (10-nov): el arreglo de Grupos de la Bandeja, dos TestFlight y documentación. Ninguno toca el Panel.
Por qué: la condición del añadido (10-nov 6:03) se escribió antes de ese merge, que es lo que pedía. Alternativa descartada: parar con `BLOQUEANTE:`, que frenaría la cola por cambios que este lote no lee.

**D1 · Orden de los tres puntos** → Gráfica (2) e iPad (3) primero; el día 1 (1) se monta encima del PR de la decisión 8 («Tienes hoy», en cola de auto-merge), que reescribe `HeroMonthView`.
Por qué: los dos tocan el mismo bloque del hero; construir sobre lo que entra evita un conflicto que nadie valida. Alternativa descartada: implementarlo sobre 2.3 sin ese PR y resolver el choque al rebasar.

**D2 · ¿Qué porcentajes se ocultan los días 1 y 2?** → Todos los de comparación con el período anterior dentro del Panel (chips de variación del hero, la gráfica, tartas, tops, necesidades, flujo) y el «vs <monto anterior>» de las tartas, con un valor de entorno que lee `VariationChip`. El % de uso de un presupuesto no es una comparación y se queda.
Por qué: el −100 % de Necesidades era un chip de variación; una sola pieza cubre todas las instancias. Alternativa descartada: apagar `showVariations` por widget (se escapan los que leen la preferencia directa).

**D3 · ¿Qué período cuenta como «día N»?** → Solo «Este mes», días 1 y 2 (umbral día 3). «Esta semana», «Este año» y los demás no cambian.
Por qué: la decisión 10 habla del día del mes («Día N de 31»). Alternativa descartada: generalizar a cualquier período recién empezado, que nadie pidió.

**D4 · La fila de inicio → hoy (B), ¿para qué métricas?** → Solo para Saldo. Con montos ocultos, solo el %. Los días 1-2 sin %. Con un solo día no sale (la gráfica se queda con su punto suelto).
Por qué: la decisión dice «la gráfica de saldo»; en Ingresos y Gastos la curva es otra cosa. Alternativa descartada: fila en las tres métricas.

**D5 · El chip «vs …»** → El chip dice la fecha real del período anterior contra la que compara («vs 20 oct»; con año si no es el actual). Sale del mismo recorte que el %, así no pueden divergir.
Por qué: es lo que pide A. Alternativa descartada: nombrar el período («vs octubre»), que no dice que la comparación corta en el mismo día.

**D6 · El eje largo** → Con varios años, «nov 2024» en vez de «nov 24», en el helper común (también lo ve Estadísticas, que sigue la regla del Panel por la decisión 27).
Por qué: «24» se leía como día. Alternativa descartada: solo el año («2024»), que con marcas a mitad de año se lee como enero.

**D7 · Margen del eje** → El margen del 10 % se calcula contando ya el saldo de hoy; antes el punto de hoy podía quedar pegado al borde. El eje sigue sin arrancar en cero.
Por qué: la decisión deja un margen en los extremos y descarta C.

**D8 · Cuadrícula del iPad (D)** → En ventana ancha, cuando «Tus finanzas» va junto a la cifra grande, las cuentas pasan de carrusel a cuadrícula de dos columnas si caben dos tarjetas de 220 pt; si no, el carrusel de siempre. El iPhone no cambia.
Por qué: «pares, nunca tres columnas» y «lo que va en media columna decide por su ancho» (reglas de layout). Alternativa descartada: cuadrícula por size class sin mirar el ancho, que en un iPad mini en vertical dejaba tarjetas de ~160 pt.

**D9 · Test por punto** → Unit tests de la lógica pura (fecha inyectada) para los tres puntos, y QA en el simulador con el reloj falso del molde de la ficha para el día 1 (la app no tiene seam de reloj para XCUITest).
Por qué: el día del mes no se puede fijar en un XCUITest sin añadir un seam nuevo al binario. Alternativa descartada: un argumento `-uitest-today` solo para esto.
