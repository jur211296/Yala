Yala
# Decidido 9-nov 2.3 · Flujo de caja: «Al 30 tendrías», real frente a estimado y el widget
card: tablero-2-3-flujo-de-caja-al-30-tendrias-real-fr-rwy5
toca: Yala/App/Views/Reports/, Yala/App/Views/Panel/, YalaWidgets/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 30, 31 y 34. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md. La cifra «Al 30 tendrías» va con maqueta, junto a la del Panel (decisión 8).

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. «¿Llego a fin de mes?» deja de tener cinco cifras distintas. Opción A, con maqueta primero en este mismo PR (junto a la del vocabulario del Panel): una sola cifra «Al 30 de noviembre tendrías S/ X», igual en el Panel y en el flujo de caja, con su cuenta (hoy · entra · sale). Reabre a propósito la cabecera del mes del lote 18 de 2.2. Vocabulario de la decisión 8.
2. Real y estimado se distinguen (opción A + B): barra de dos tonos (gastado sólido, lo que falta rayado); «Real» y «Estimado» como únicas palabras; «Pago programado» pasa a «pago planificado». «≈» sigue significando solo «convertido».
3. Widget: el tramo punteado deja de confundir (opción A, reabre la 12A): punteado con color propio y separado de la raya del año anterior, y una cifra corta «Estimado S/ X al 31 dic» donde quepa (palabra «Estimado», no «≈»).

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Primero la maqueta de la cifra «Al 30 tendrías» en el PR, con la opción ya elegida; no reabras la decisión. Alinea palabras con el lote del vocabulario «Tienes hoy» / «Te queda».
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (resueltas en autónomo, modo semi)

Precondición medida: `origin/2.3..origin/2.2` = 16 commits (cierre de 2.2: Grupos, Bandeja, release y docs). 2.2 entró en
2.3 el 10-nov (`d4c585dbd`); ninguno de los 16 toca Reportes, Panel ni widgets. Se sigue. Rama recolocada sobre
`origin/2.3` (nacía de 2.2).

1. **«Al 30 tendrías» = la misma cuenta del Panel**, no otra: saldo vivo de las cuentas que suma el Panel (sin filtro,
   con el interruptor de Grupos) + `ProjectedFlowBuilder` hasta fin de mes, sin filtros de sesión. Pieza compartida
   nueva; el Panel no cambia de cálculo. Solo en el mes en curso; los demás meses, la cifra del mes de antes.
2. **Cuenta debajo**: «Tienes hoy» (clave de `L10n.Panel.Hero`) · «Falta entrar» · «Falta salir», más la fuente
   («Estimado con tu plan…»). La línea del neto pasa a «Este mes te quedaría».
3. **Rótulo del Panel y Tendencias**: «Al <fecha fin> tendrías» (Saldo), «Gastos al <fecha>», «Ingresos al <fecha>».
   La fecha es el fin del período proyectado; con otro año, con año.
4. **Vocabulario del mes**: «te sobran/sobrarían/sobraron» → «te queda/quedaría/quedó» (regla de l10n: nunca «te
   sobra»); «te faltan» se queda. «Te sobran al mes» del armado → «Te queda al mes».
5. **Horizonte y «Empezaste con»** se quedan como están (otra pregunta, con su fecha). Su base es el saldo inicial del
   plan, no «Tienes hoy»: va a «Encontrado», no se toca aquí.
6. **Real/estimado**: barra de dos tonos solo en el mes en curso (real sólido, lo que falta rayado); «Gastado» y
   «Recibido» → «Real»; «Te quedan» / «Te falta recibir» del flujo → «Estimado que falta»; «Proyección» → «Estimado»;
   «Proyección de saldo» → «Saldo estimado»; «pago programado» → «pago planificado». «Te pasaste» se queda.
   `BudgetProgressBar` no se toca (es de Presupuestos): barra propia del flujo.
7. **Widget**: color propio para lo estimado (ámbar `#F59E0B`, igual en Gasto y Saldo); cifra «Estimado S/ X al 30 nov»
   solo en el mediano, con punto del mismo color; oculta con «Ocultar montos».
8. **Tests**: unit por punto (lógica pura), parity Panel = flujo; XCUITest del mes en curso si el índice lo pide.
