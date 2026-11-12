---
esfuerzo: high
release: no
---
# Tests del CI en verde: 12 tests del contexto financiero de la IA que dependen de la fecha, pagos programados los días 31 y Nuevo registro a medias que vuelve vacío

## PRIMERO: 12 tests de FullFinancialContextBuilderTests que dependen de la fecha
El check `tests` de 2.2 quedó rojo en el run https://github.com/jur211296/Yala/actions/runs/41274992024 (corrió tras fusionar #722). Fallaron 12 tests: ranking de categorías, presupuesto con límite, top de transacciones por subcategoría, top de transacciones con monedas mezcladas, anomalías, multimoneda, top 20 de comercios, desglose de necesidades, cubeta sin categoría, cuentas excluidas, caché de 60 s y ajustes de saldo.

- La causa NO es #722 ni los widgets. Estos tests dependen de la fecha: el helper `currentMonthDate` limita a «ahora menos 1 hora». Como corrieron a las 00:30 del 1-nov (Lima), la fecha cayó en el 31-oct y los movimientos quedaron fuera del mes. El archivo no cambia desde el 12-oct, y #721 salió verde a las 22:12.
- Ese job ya se relanzó y debería salir verde pasada la 01:00. Si sale verde, el rojo de esa noche está explicado, pero el arreglo sigue haciendo falta.
- Arreglo: usa una fecha fija inyectada en vez de Date.now/`Date()`, como ya hace otro test del mismo archivo con el 15-oct-2026. Quita la dependencia del reloj en `currentMonthDate`.
- Revisa en toda la suite los tests con el mismo patrón (helpers con "ahora", inicio de mes o de semana, «ahora menos N»), y corrígelos igual.
- Cómo se sabe que está hecho: los 12 pasan aunque el reloj del sistema esté en el primer día del mes a las 00:30 (pruébalo), y `tests` queda verde en 2.2.

## Contexto
Jürgen aprobó este plan el 31-oct a las 22:03 (Lima): «Sí, aplícalo así». Su regla del 2026-10-30 es que todo entra en 2.2 antes del barrido QA, nada a backlog.

Zona: la suite unitaria (pagos programados) y ExternalEntryForeignSheetUITests.

Cards:
- `tablero ver tablero-fullfinancialcontextbuildertests-falla-e-tyzh` — FullFinancialContextBuilderTests falla en la primera hora de cada mes (12 casos)
  - Problema: es el mismo fallo de «PRIMERO», medido por la sesión del congelamiento el 1-nov a las 00:15 (Lima). `currentMonthDate()` devuelve min(inicio de mes + offset, ahora − 1 h), y en la primera hora del día 1 cae en el mes anterior. Revisa también las suites hermanas (ChatContextPanelParityAndMonthToDateTests).
  - Hecha cuando: la suite pasa con el reloj en el día 1 a las 00:15 y a mitad de mes, y no queda otro test con el mismo patrón de fecha. Cierra esta card junto con la del CI en rojo.
- `tablero ver tablero-test-de-pagos-programados-falla-los-dias-8hs2` — Test de pagos programados falla los días 31: «un mes después» se calcula desde una fecha recortada
  - Problema: Medido el 2026-10-31 en el encargo S30 (suite unitaria completa, 12094 tests): solo falla InboxDismissScheduledDraftTests.payingEarlyOnTheDayOfAnOccurrenceCoveredByAnotherTransaction_advances (L340). Con la ocurrencia hoy (31-oct), next = 30-nov y el test espera next + 1 mes = 30-dic; el código avanza desde el ancla. Falla también corrido solo y el diff de S30 no toca pagos programados. Falta decidir si el bug es del test (fecha relativa a hoy) o de producto (un pago del 31 que se adelanta).
  - Hecha cuando: El test pasa cualquier día del mes (fijar el reloj o medir con un día 31 y 28-feb) y, si es producto, el avance de un pago del 31 cae en el día correcto.
- `tablero ver tablero-un-nuevo-registro-a-medias-vuelve-vacio-5xj4` — Un «Nuevo registro» a medias vuelve vacío o cerrado al entrar a Yala desde fuera (solo en el runner del CI)
  - Problema: ExternalEntryForeignSheetUITests cae 1-3 veces por noche desde el 23-oct en los tres enlaces (voz, foto compartida, enlace al Panel): el formulario vuelve con 0.00 o cerrado. Con el PR #690 el test ya comprueba que el importe estaba escrito antes de salir, así que no es el tecleo. En local pasa. Ticket: tickets/backlog/half-filled-form-loses-its-amount-after-an-external-entry-on-ci.md
  - Hecha cuando: Causa medida en el CI y el caso de voz verde tres noches seguidas, o decisión de producto tomada

## Qué se pide
1. Lee cada card y su ticket, si tiene. Busca la causa raíz antes de tocar código.
2. Cumple el «hecha cuando» de cada card, con tests (unitarios, source-scan o XCUITest según el caso) y, si es visual, vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Nada fuera de las cards de esta sesión.
- marketing/ ni Web/ (salvo el README de marca, si está en las cards).
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-01, autocontestado)

- **Cómo se prueba «reloj en el día 1 a las 00:xx»**: con `TEST_RUNNER_TZ=Etc/GMT+<hora UTC>`, el mismo mecanismo que el CI usa para Lima. La zona deja la hora local del simulador en 00:MM del 1-nov sin tocar el reloj de la Mac. Antes del arreglo da los 12 rojos exactos del CI; después, verde. Los rojos que salen solo por la zona (fixtures fijados a Lima) se separan con un control a mediodía en otra zona y con Lima, y no entran: el CI corre en Lima a propósito.
- **FullFinancialContextBuilderTests**: `now` fijo de la suite al 15-oct-2026 a mediodía (el que ya usaba `periodComparison`), y todos los `Date.now` del fichero salen. El builder ya aceptaba `now:`; producción no se toca.
- **Mismo patrón en el resto**: donde el código acepta `now:`, fecha fija (`PreviousPeriodHelperTests`, la semana del año pasado, que caía del 1 al 3 de enero de 2027). Donde lee el reloj real por dentro (Registros, presupuestos del Panel y de Planificación), `aMomentAgoToday()`: «hace 60 s» sin salir de hoy, en `TestHelpers`. Inyectar `now:` en esos ViewModels es producción y queda fuera.
- **Pagos programados los días 31**: el oráculo ya se corrigió en 2.2 (566af1318, 31-oct) y el producto ancla bien al `dayOfMonth`. Lo que faltaba del «hecha cuando» —que pase cualquier día— se cubre con un gemelo de fechas fijas (31-oct, 31-ene, 31-ene bisiesto, 30-ene y 28-feb) que no depende de hoy. No es bug de producto.
- **Formulario a medias en el CI**: no se reproduce en local y la causa no se puede medir sin una nocturna. Se instrumenta (solo con `-uitest`): la app expone pid, escenas conectadas/desconectadas, desmontes de la barra de pestañas y formularios nuevos, y el XCUITest lo cita al fallar. La card queda en curso esperando la nocturna; no se salta el test. Lanzar una nocturna entera por dispatch desde la rama se descarta: ocupa los `macOS` del CI ~3,5 h por un caso que cae 1-3 veces por noche.
