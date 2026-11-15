Yala
# Decidido 9-nov 2.3 · Registros: saltar de mes, el año en la cabecera y «Período»
card: tablero-2-3-registros-saltar-de-mes-el-ano-en-la-ryqg
toca: Yala/App/Views/Records/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 17, 79, 73 y 74. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/31-registros/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 4 puntos:
1. «Todo el tiempo» deja saltar a un mes y la cabecera lleva año cuando toca (T1 + T2): separador de mes fijo y tocable, cabecera de día con año y total. Año solo cuando el día no es del año actual.
2. Las cabeceras de día llevan fondo y dejan de montarse sobre las filas.
3. Una sola grafía, «Período», en toda la app.
4. «Nota contiene...» usa puntos suspensivos tipográficos y el marcador de monto sigue el formato de la persona, no un «0.00» fijo.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 12-nov, nocturno; auto-contestado)

Medido antes de tocar: `origin/2.3..origin/2.2` = 0 commits (2.3 ya tiene todo 2.2). `git log origin/2.3..origin/2.2` vacío en las vistas tocadas.

1. **Saltar de mes (T2).** La lista de Registros se agrupa por mes; el separador del mes va fijo arriba **solo si la lista cubre dos meses o más** (con «Esta semana» o «Este mes» sobra, como dice la propia maqueta). Tocarlo abre un menú del sistema con los meses («Octubre 2026», debajo «182 registros · S/ -6,420») y elegir uno lleva la lista a su primer día. La cifra es lo gastado del mes, con el mismo cálculo que el calendario (`DailySpendingCalculator.dayTotals`). Vale en Registros y en Estadísticas › Registros (es la misma lista).
2. **Cabecera de día (T1).** «vie 17 oct» + lo gastado ese día a la derecha; con año («vie 4 jul 2025») solo si no es del año en curso. Un día sin gasto (solo ingresos) no lleva cifra. Buscar y Grupos no cambian (usan la misma pieza con su formato de siempre).
3. **Fondo de la cabecera (79).** 2.2 ya quitó las cabeceras de día fijas (PR del unslop de Registros, «la fecha no se monta»), así que hoy no se montan. Lo único fijo de la lista pasa a ser el separador de mes, y lleva banda opaca: nada se lee debajo. Las de día van con el scroll y sin fondo, como la maqueta T2.
4. **«Período».** Todos los textos en español (es, es-419, es-AR, es-ES; app, plurales y widgets) pasan de «periodo/periodos» a «período/períodos». Los comentarios y el contexto de Yala IA no se tocan (no se ven).
5. **«Nota contiene…» y el 0.00.** Puntos suspensivos tipográficos en ese texto en los 16 idiomas. El marcador del monto del filtro pasa a ser un cero con los decimales que la persona eligió y el separador de su región (el mismo que pone el teclado decimal), y lo escrito se lee con ese separador: si el marcador dice «0,00», «12,50» filtra 12,50 y no 12. El resto de campos de monto con «0.00» fijo (Nuevo registro, Grupos, Bandeja) quedan fuera: no eran de esta decisión.
6. Textos nuevos: uno solo, «Ir a otro mes» (título del menú y pista de VoiceOver), en 16 idiomas. El recuento usa el plural que ya existe («182 registros»).
