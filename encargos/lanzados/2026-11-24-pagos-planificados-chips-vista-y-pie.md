---
toca: Yala/App/Views/Planning/ScheduledPaymentsListView.swift, Yala/App/Views/Planning/ScheduledPaymentsView.swift, Yala/App/Views/Planning/PagosRecurrentes/RecurringProposalsSettingsView.swift, Yala/App/Views/Planning/PagosRecurrentes/PagosRecurrentesText.swift, Yala/App/Views/Planning/LogoComercio/PagoLogoComercio.swift, Yala/App/Views/Planning/SubscriptionBrandBadge.swift, YalaTests/PagosPlanificadosChipsVista/, tickets/backlog/2026-11-24-pagos-planificados-chips-vista-y-pie.md, tickets/done/2026-11-24-pagos-planificados-chips-vista-y-pie.md
esfuerzo: medium
---
# Pagos planificados: chips de vista con texto, ícono de subcategoría cuando no hay logo y el enlace del pie pegado al final

## Contexto
Jürgen probó la 2.3 en su iPhone (24-nov, 06:08 y 06:09 Lima, con capturas) y pidió dos cambios en Planificación › Pagos planificados.

1. **Selector de vista.** Debajo del selector de mes («Próximo mes») hoy hay tres botones redondos solo con ícono, alineados a la derecha (`ForEach(PaymentsViewMode.allCases)` y `viewModeButton(for:)` en `ScheduledPaymentsListView.swift`, alrededor de las líneas 250 a 270). Hay que cambiarlos por **chips con texto, alineados desde la izquierda: «Lista», «Línea de tiempo», «Calendario»** (ícono más texto si queda bien), con el seleccionado resaltado como los demás chips de la app. Que sean más visibles y aprovechen el ancho. Con texto grande (Dynamic Type) o en idiomas largos, que se desplacen en horizontal o bajen de línea, nunca recortados. Mantener lo que ya hay: animación respetando Reducir movimiento, la vista elegida persistida y la accesibilidad (etiqueta y estado seleccionado).
2. **Hueco bajo la lista.** Debajo de la tarjeta del timeline queda un espacio vacío enorme antes del enlace «Pagos que se repiten» (`RecurringProposalsFooterLink` en `RecurringProposalsSettingsView.swift`, puesto en `ScheduledPaymentsView.swift` después de `ScheduledPaymentsListView`). Hay que encontrar de dónde sale ese alto (¿altura mínima de la lista, un relleno para el botón flotante, un `Spacer`?) y quitarlo, para que el enlace quede **cerca del final de la lista, con aire, pero sin pegarse**: más o menos el espacio normal entre secciones (`DS.Spacing.lg`/`xl`). El texto cambia a **«Ver más pagos que se repiten»** (clave `pagosRecurrentes.footer.link`; la hoja y el título siguen diciendo «Pagos que se repiten»). Traducir el nuevo texto en todos los idiomas del catálogo, en español neutro latinoamericano para `es-419`. El último pago no puede quedar tapado por el botón flotante «+» ni por la barra de abajo: si hace falta reservar espacio para eso, que sea solo lo justo.

3. **Ícono cuando no hay logo** (Jürgen, 06:15 Lima, con captura). En la línea de tiempo, los pagos sin logo de comercio (Sueldo Zeal, Préstamo SIP, Renta, Hevy Pro…) se quedan sin ícono delante del nombre, porque hoy, sin logo, no se pinta nada (comentario en `ScheduledPaymentsListView.swift`, alrededor de la línea 232). El plan B es **el ícono de la subcategoría del pago** (y si no tiene subcategoría, el de la categoría), del mismo tamaño y en el mismo lugar que el logo, para que todas las filas queden alineadas. Hay que aplicarlo **en las tres vistas**: lista, línea de tiempo y calendario (en el calendario, la marca del día usa el ícono en lugar del punto cuando no hay logo, respetando el límite de marcas por celda y el aro con el color de estado). El orden queda así: primero el logo del comercio, después el ícono de la subcategoría y por último el de la categoría. Usa el mismo ícono y color de subcategoría que ya se ve en Registros. Agrega tests de ese orden en la misma carpeta de tests, sin romper `YalaTests/PagosLogoComercio/`.

Revisa las tres vistas (lista, línea de tiempo y calendario), con pocos y con muchos pagos, y en las pestañas del mes actual y del próximo.

Simulador y equipo: antes de usar simulador, comprueba si el iPhone 14 conectado por DeviceMCP está libre y úsalo si conviene; nunca lo des por ocupado sin comprobarlo. En la Max tienes permiso para un segundo simulador (tope 2); en la Mini, tope 1. En la Mini, pipeline serial: limpiar sims muertos, tu DerivedData y las cachés de XcodeBuildMCP de worktrees retirados (sin preguntar), build `xcodebuild -jobs 2` sin sim, arrancar 1 sim, tests y capturas, apagar y borrar el sim. Al cerrar, borra tu DerivedData.

## Qué NO hay que tocar
- La lógica de pagos planificados, el banner de propuestas de arriba, ni la hoja «Pagos que se repiten».
- Presupuestos ni el resto de Planificación.
- Commits y PR sin firma de IA.

## Cómo se sabe que está bien
- Capturas de antes y después en `capturas/`: las tres vistas, en modo claro, modo oscuro, con texto grande y con el iPhone girado, más el final de la lista con el enlace.
- Tests de lo que tenga lógica (orden y nombre de las vistas, persistencia) en `YalaTests/PagosPlanificadosChipsVista/`, y los tests existentes de Planificación en verde.
- PR contra `2.3` con el CI real en verde y mergeado antes de `/cerrar-total`. Si a los ~45 minutos el CI sigue rojo por algo ajeno al PR, cerrar y anotarlo.

## Paso 0 — decisiones (resueltas en semi, sin consultar: menores y reversibles)

1. **Chips de vista**: ícono + texto, alineados a la izquierda, en un scroll horizontal (con texto grande o idiomas largos se desplazan, nunca se recortan). Seleccionado con el relleno de acento que se desliza (`matchedGeometryEffect`), como `SelectionChip`/`GenericSegmentedPill`. Se conservan Reducir movimiento, háptico, etiqueta y estado seleccionado.
2. **Persistencia de la vista**: el encargo da por hecho que la vista elegida se guarda; medido: NO se guarda (`paymentsViewMode` es una propiedad en memoria del ViewModel). Se añade la persistencia en `AppPreferences` (regla de `swiftui-ds.md`), con su test.
3. **Hueco bajo la lista**: sale de `.padding(.bottom, DS.Spacing.safeBottom)` (100 pt) que `ScheduledPaymentsListView` añade «para el FAB» ENTRE la lista y el enlace del pie. Se quita de ahí; el enlace va a `DS.Spacing.xl` del final de la lista, y el sitio para el «+» flotante va DEBAJO del enlace, justo lo de un botón (`DS.Button.fabStackClearance(buttons: 1)`).
4. **Ícono sin logo**: se reusa el criterio común que ya pinta la lista y el Flujo de caja (`ScheduledPaymentsViewModel.paymentDisplayProperties`: subcategoría → categoría → el de su tipo). En la práctica ninguna subcategoría trae color propio, así que el color es el de la categoría, como en Registros. Orden fijado en una función pura (`PagoDistintivo.fuente`) con tests.
5. **Calendario**: sin logo, la marca es el ícono en 12 pt con el aro del estado, igual que la del logo. Como todas las marcas pasan a ser de ese tamaño, el límite por celda es siempre 2 (antes 3 solo cuando eran puntos). Se actualiza el source-scan de `YalaTests/PagosLogoComercio/` que contaba la línea del límite viejo.
6. **Texto «Ver más pagos que se repiten»**: los 16 idiomas del catálogo, a mano.
7. **Archivos fuera de `toca:`**: `ScheduledPaymentsViewModel.swift` (persistencia), `AppPreferences` (clave nueva), `Localizable.strings` ×16, `PagoLogoComercioTests.swift`, `qa/coverage-index.json` y un conductor de capturas en `YalaUITests/PagosPlanificadosChipsVista/`.
8. **Equipo**: el iPhone 14 no está conectado a la Max (Device MCP solo lista simuladores); se usa el simulador iPhone 17 Pro.
