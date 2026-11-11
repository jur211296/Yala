Yala
# Decidido 9-nov 2.3 · Panel: «Tienes hoy» y «Te queda» (maqueta primero)
card: tablero-2-3-vocabulario-del-saldo-tienes-hoy-y-t-hzhi
toca: Yala/App/Views/Panel/, Yala/App/Views/Statistics/, YalaWidgets/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 8 (opción C, con maqueta primero). Card reutilizada. Fichas: docs/ux/revision-vistas-2.3/30-panel/ficha.md, 35-estadisticas/ficha.md y 36-reportes-flujo/ficha.md. Tres hallazgos: PN-1 «Balance»; 35 P4 tres nombres; «Disponible» del widget frente a «Saldo» del Panel.

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. Vocabulario único en toda la app, con maqueta primero en este mismo PR (opción C, sin reabrirla): cifra grande = «Tienes hoy» (no sigue el período); debajo, el mes en curso en presente: «Te queda S/ X» (nunca «te sobró»/«te sobra»); meses cerrados en pasado; sin rótulos «entró/salió» (bastan las flechas verde y roja, con etiqueta para VoiceOver). Píldoras y período mueven solo la línea del mes; una cuenta elegida = su saldo; «≈» con varias monedas; saldo negativo = «Debes S/ X»; modo «Solo gastos» conserva «Gastos de <mes>»; el ojo oculta las dos. «Tienes/Saldo» = lo de las cuentas; «Te queda» = entró − salió; «Balance» y «Disponible» desaparecen.
2. En Estadísticas, «Balance», «Saldo» y «Saldo de cuentas» (tres cifras, nombres casi iguales) pasan al mismo vocabulario.
3. El widget deja de decir «Disponible» y usa el mismo vocabulario que el Panel.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Primero la maqueta en el PR, con la opción C ya elegida; el detalle fino se cierra con esa maqueta en la mano, sin reabrir la decisión. Luego se aplica en Panel, Estadísticas y el widget.
- Coordina el vocabulario con el lote «Al 30 tendrías» (decisión 30), que usa las mismas palabras.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 11-nov 04:40 Lima, modo nocturno)

Medido antes de empezar:
- `git rev-list --count origin/2.3..origin/2.2` = 16. Lo que falta en 2.3 es el arreglo de Grupos (borradores
  duplicados), la subida de TestFlight 2.2 y documentación; ninguno toca Panel, Estadísticas ni widgets
  (`git diff --stat` del merge-base a 2.2 sobre esas rutas: vacío). Cuenta como «casi 0»: se sigue.
- Rama recreada sobre `origin/2.3` (nacía de 2.2).
- Los tres hallazgos siguen vivos en 2.3: «Balance de noviembre» como cifra grande del Panel
  (`PanelHeroFigureLogic`), «Balance del período» / «Saldo de cuentas» / «Saldo» en Estadísticas, y «Disponible» en los
  widgets de saldo y de resumen del mes.

Decisiones de detalle (la opción C no se reabre; esto es el «detalle fino» que cierra la maqueta):
1. **Cifra grande**: saldo de las cuentas que suma el Panel (`panelTotalBalance`, ya respeta la cuenta elegida), rótulo
   «Tienes hoy». Negativo: «Debes hoy» con la cifra sin signo. Con varias monedas, «≈» (ya lo trae el saldo). El
   período no la mueve. Sin cuentas, S/ 0.
2. **Línea del mes**, debajo: «Te queda S/ X» en un período en curso; «Te quedó S/ X» en uno cerrado (mes pasado,
   año pasado, rango que acabó antes de hoy); el mes pasado lleva su nombre («En octubre te quedó S/ X»). Con un mes
   en rojo la cifra va con su signo («Te queda −S/ 200»): la decisión no pide otra palabra y así cuadra con la resta.
3. **Píldoras**: siguen las flechas verde y roja con su importe, sin rótulo en pantalla («Entró/Salió» solo para
   VoiceOver, como ya estaba). Con una píldora puesta, la línea del mes dice lo que filtra («Gastos de noviembre S/ X»)
   y la cifra grande no cambia.
4. **Solo gastos**: el hero se queda como estaba (cifra = gasto del período) y el rótulo pasa de «Gastado» a «Gastos de
   <mes>», como pide la decisión.
5. **Ojo**: oculta las dos cifras (la grande y la de la línea del mes); ya lo hace `AmountText` con `amountsHidden`.
6. **Estadísticas**: «Balance del período» → «Te queda» / «Te quedó» según el período; «Saldo de cuentas» (Distribución)
   → «Tienes hoy» en un período en curso y «Tenías al cierre» en uno cerrado (su cifra es el saldo a esa fecha); el
   «Balance» que VoiceOver decía en la tarjeta «Saldo» de Tendencias → «Saldo»; «Tu balance se mantiene estable» →
   «Lo que te queda se mantiene estable»; el nodo «Disponible» del flujo → «Te queda» / «Te quedó».
7. **Widgets**: «Disponible» → «Saldo» en el título, la galería y la configuración de los widgets de saldo (inicio y
   pantalla bloqueada) y en la cifra de «Resumen del mes». Es el saldo de las cuentas al cierre del período elegido:
   «Tienes hoy» mentiría con «Mes pasado».
8. **Fuera, a propósito**: «Disponible» del plan de flujo de caja (es del lote «Al 30 tendrías», decisión 30, que usará
   estas mismas palabras), «Tu balance» de Grupos (es deuda entre personas, otro concepto) y «Disponible» de la
   calculadora de tarjeta del onboarding (línea de crédito disponible, otro concepto). En español «Balance inicial» de
   la cuenta pasa a «Saldo inicial» (solo texto; BRAND-VOICE ya pide «Saldo»).
9. **Textos nuevos** en los 16 idiomas; los textos cambiados de clave existente, en las cuatro variantes de español
   (el resto de idiomas ya decía su palabra para «saldo»).
10. **Tests**: un unit por punto (lógica del hero del Panel, rótulos de Estadísticas por período, claves del widget) y
    el XCUITest del hero del Panel que ya existe, ajustado al rótulo nuevo.
