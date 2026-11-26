Yala
# Primeros pasos: que cada paso cuente bien (solo gastos de cero, guía del registro, pago planificado en el widget, paso 7 y Grupos)
---
toca: Yala/App/Logic/SetupDeckLogic.swift,Yala/App/Logic/OnboardingStepPlan.swift,Yala/App/Logic/OnboardingAccountChoiceLogic.swift,Yala/App/Logic/OnboardingPurposeSelectionLogic.swift,Yala/App/Views/Onboarding/OnboardingView.swift,Yala/App/Views/Panel/SetupChecklistCard.swift,Yala/App/Views/Panel/PrimerosPasosPanelPresentations.swift,Yala/App/Views/Transactions/NewTransactionView.swift,Yala/App/ViewModels/NewTransactionViewModel.swift,Yala/App/Views/Transactions/NewRecordTutorialGuide.swift,Yala/App/ViewModels/PanelViewModel.swift,Yala/App/Views/Panel/ScheduledPaymentsWidget.swift,Yala/App/Logic/HomeScreenTutorialLogic.swift,Yala/App/Views/Panel/PrimerosPasosHomeScreenPresentation.swift,Yala/App/Logic/PrimerosPasosPlanningLogic.swift,Yala/App/Views/Panel/PrimerosPasosPlanningPresentations.swift,Yala/App/Views/Panel/PanelView.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/PrimerosPasosCuentaBien,YalaUITests/PrimerosPasosCuentaBien,tickets/backlog/2026-11-25-primeros-pasos-cada-paso-cuenta-bien.md,tickets/done/2026-11-25-primeros-pasos-cada-paso-cuenta-bien.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
---

Pedido de Jürgen (25-nov, 18:21 Lima): encolar en lotes los hallazgos de la observación en vivo del iPhone 14 (PR #1181, https://github.com/jur211296/Yala/pull/1181). Este es el primer lote: fallos de lógica que hacen que el mazo de Primeros pasos mienta (pasos hechos que salen «para después» y al revés) y un pago que «desaparece». Esfuerzo alto porque toca el alta de la cuenta y la lógica del mazo, ya cubiertas por pruebas que no hay que romper.

## Contexto
- Yala Dev 2.3 (10) probada por Jürgen desde cero el 25-nov. Bugs de cuenta del PR #1176 ya están en 2.3.
- Cards del tablero de Yala 2.3 que cubre este lote (búscalas por título con `tablero listar --proyecto Yala`):
  1. «Primeros pasos «Solo gastos»: el paso 1 se hace de cero, sin cuenta creada sola»
  2. «Guía del primer registro se salta «Tu cuenta ya está puesta» con una cuenta de dos monedas»
  3. «Widget de Pagos planificados: mostrar el próximo vencimiento aunque caiga el mes que viene»
  4. «Paso 7: ver todas las historias hasta «Terminar» no cuenta como hecho»
  5. «Grupos en Primeros pasos: «Ahora no» tras aceptar la intro cuenta como hecho, y el aviso «lo viste al entrar»»

## Qué se pide
1. **Solo gastos de cero (decisión de Jürgen, 25-nov 17:19, revierte la del 19-nov):** con «Solo gastos», el paso 1 no sale hecho y la persona crea su cuenta de cero, igual que con «Ingresos y gastos». Quitar la cuenta «Gastos <moneda>» que hoy Yala crea sola, el paso 1 dado por hecho, la línea `setup.deck.firstExpense.note` («Tus gastos van a…») y ajustar la compuerta del Panel (`PrimerosPasosPanelGate.make` en `SetupDeckLogic.swift`). Cuentas ya creadas así no se tocan.
2. **Guía del primer registro:** con una cuenta de dos monedas no se salta el paso «Tu cuenta ya está puesta» (`hasSingleAccount` en `NewTransactionView.swift` cuenta cuentas, no cuentas visibles/por moneda; revisar `loadData` sin filtro).
3. **Widget de Pagos planificados:** si el próximo vencimiento cae el mes que viene, el widget lo muestra en vez de quedar vacío (`PanelViewModel` ~`paymentDatesInMonth` / `upcomingPayments` y `ScheduledPaymentsWidget.swift`, vacío si `monthlyTotal == 0`).
4. **Paso 7:** ver todas las historias hasta «Terminar» cuenta como hecho (`HomeScreenTutorialLogic.swift`: `.finished(anyDone)` → hoy `.skipped` si ninguna; `PrimerosPasosHomeScreenPresentation.swift`, `afterTutorial`).
5. **Grupos en Primeros pasos (decisión de Jürgen):** ver y aceptar la intro basta; «Ahora no» al final cuenta como hecho (`GroupsTutorialLogic.advancesDeck` / `marksOnboardingSeen`, `afterGroups: markSkipped(.groups)`). Y quitar el aviso «Grupos ya lo conoces: lo viste al entrar» que sale justo después de salir de la intro (`startGroupsStep` en `PanelView.swift`, texto `pasos23.groups.alreadySeen`).

## Qué NO hay que tocar
- Guías de lugar, gesto de las historias, aviso «viven en Más», paso 6 y la intro de Grupos tras cerrar sesión: van en el lote siguiente.
- Textos de pulido (selector de moneda, «Presupuesto» chico, nombre cortado, «paso 2 de 3», paywall, confeti): van en el tercer lote.
- Oferta Pro y Primeros pasos centrado: esperan maqueta de Jürgen.

## Cómo se sabe que está bien
- Cuenta nueva «Solo gastos»: Primeros pasos arranca en 1 de 7, sin cuenta creada sola; al crear la cuenta, el paso 1 queda hecho y su tarjeta aparece.
- Cuenta de dos monedas: la guía del registro muestra «Tu cuenta ya está puesta».
- Pago planificado con vencimiento el mes que viene: aparece en el widget del Panel.
- Pasar las 6 historias del paso 7 hasta «Terminar» deja el paso hecho; «Ahora no» tras la intro de Grupos deja el paso 5 hecho y no sale «lo viste al entrar».
- Pruebas nuevas en `YalaTests/PrimerosPasosCuentaBien/` verdes y las existentes de Primeros pasos, Panel progresivo y solo gastos sin romperse (las que cambian por la decisión nueva, se actualizan diciendo por qué).

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Lee la bitácora de la observación: `docs/qa/observacion-iphone14-2026-11-25/bitacora.md` (hallazgos con hora, captura, causa probable y archivo). Página de la observación: https://claude.ai/artifact/WURtsKhAZqZ83dhddeVmvi
- Cada arreglo con su prueba unitaria en la carpeta de pruebas de este lote (no en carpetas de pruebas ajenas). Textos nuevos en los 16 idiomas de `Localizable.strings`, español neutro latinoamericano en `es` y `es-419`.
- Verificación visual: puedes usar el iPhone 14 por DeviceMCP (Yala Dev ya instalada; Jürgen puede estar usándolo: si está en uso, no lo toques y usa simulador) o, en la Max, un segundo simulador además del de otra sesión. En la Mini, un solo simulador. Apaga y limpia los simuladores que enciendas.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo.
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Antes de diseñar algo visual, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración.
- Por cada card del tablero que cierres, muévela a done con `tablero mover ... --a done --agente frank` al terminar, con su «hecha cuando» cumplido.

## Cierre
- Un solo PR a `2.3` con todo el lote, auto-merge activado, y cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Capturas antes/después en `capturas/` del worktree para lo que se ve.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen.
- Sin firma de IA en commits, PR ni textos. Español neutro latinoamericano en todo lo que lea Jürgen.

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: ninguna es vital)

Ficheros: los de `toca:` más `WelcomeConversationView.swift`, `SetupChecklistManager.swift`, `SetupDeckProgress.swift`,
`SetupStepRow.swift`, `HomeScreenTutorialFlowView.swift` (solo comentario), `WidgetInfoSheet.swift`, `L10n.swift` y una
lógica nueva `ScheduledPaymentsUpcomingLogic.swift`; pruebas que cambian por las decisiones nuevas en sus carpetas.

1. **Solo gastos de cero.** El alta deja de crear «Gastos <moneda>»; `PrimerosPasosPanelGate.make` pierde el parámetro
   del modo (misma regla en los dos); se borran la línea «Tus gastos van a…» (código y clave en 16 idiomas) y el
   parámetro `note` de la fila de pasos, que solo la usaba. Cuentas ya creadas: intactas (no hay migración).
   No se toca el alta antigua de «Activar Yala completo» (`OnboardingView`): fuera del alta nueva.
2. **Guía del registro.** «Una sola cuenta» = cuentas con `isBillableUserAccount` (sin archivadas, sistema ni líneas de
   moneda). Única instancia del patrón (`accounts.count <= 1`) en `Yala/App`.
3. **Widget de pagos (opción 1 de Jürgen).** Con el mes de hoy a la vista, cada pago sin nada pendiente este mes suma
   su siguiente vencimiento (hasta 24 meses, sin saltados) a «próximos»; totales, anillo y «por pagar» siguen siendo del
   mes. El widget pequeño, con total 0, enseña «Próximo pago · nombre · fecha» en vez del vacío (reusa
   `scheduled.next.first`). La ficha «Con tus datos» suma «Próximo pago: X, el 20 de diciembre.» (clave nueva, 16 idiomas).
4. **Paso 7.** `.finished` → hecho siempre (con o sin «Enséñame cómo»); «Omitir este paso» sigue omitiendo.
5. **Grupos.** «Ahora no», crear y unirse → hecho; «Omitir» → para después; «Atrás» → nada. El aviso `alreadySeen` pasa a
   texto neutro («Ya conoces Grupos. Seguimos con el paso 6.»), como pide la card («texto neutro»), en vez de quitarlo:
   sigue haciendo falta para quien vio Grupos en la bienvenida o en su pestaña.
