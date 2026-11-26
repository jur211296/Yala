Yala
# Guías y avisos que señalan donde deben: gesto de historias, «viven en Más» con la barra desplegada, foco del paso 6 e intro de Grupos tras cerrar sesión
---
toca: Yala/App/Views/Onboarding/PrimerosPasos/TutorialStoryPage.swift,Yala/App/Tips/PlaceGuide.swift,Yala/App/Tips/PlaceGuideOverlay.swift,Yala/App/Views/Shared/TabBarArrivesExpandedModifier.swift,Yala/App/Views/Panel/PanelView.swift,Yala/App/Views/More/MoreView.swift,Yala/App/Services/AppPreferences.swift,Yala/App/Logic/CloudSignOutFlowLogic.swift,Yala/App/Logic/GroupsOnboardingLogic.swift,Yala/Utils/DataWipeService.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/GuiasSenalanBien,YalaUITests/GuiasSenalanBien,tickets/backlog/2026-11-25-guias-y-avisos-senalan-donde-deben.md,tickets/done/2026-11-25-guias-y-avisos-senalan-donde-deben.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/primeros-pasos-cada-paso-cuenta-bien
---

Pedido de Jürgen (25-nov, 18:21 Lima): encolar en lotes los hallazgos de la observación en vivo del iPhone 14 (PR #1181, https://github.com/jur211296/Yala/pull/1181). Segundo lote: la capa de guías (historias, avisos de lugar, foco del paso 6) y sus marcas de «ya visto». Va después del primer lote porque los dos tocan `PanelView.swift` y los textos.

## Contexto
- Cards del tablero de Yala 2.3 que cubre este lote (búscalas por título con `tablero listar --proyecto Yala`):
  1. «Intros y historias de Primeros pasos: el gesto vale en toda la zona entre las barras y el botón»
  2. «Aviso «viven en Más» apunta a la barra de pestañas plegada: mientras se ve, la barra va desplegada»
  3. «Paso 6: la guía de gráficas no enfoca si Más viene desplazado, y al terminar deja a la persona en Más»
  4. «La intro de Grupos vuelve a salir tras cerrar sesión aunque ya se aceptó»
  5. «Guía «Tus gráficas viven en Más»: destacar el botón Más» (del recorrido del 13-nov: el globo 2 de 2 solo tiene «Omitir» y hay que adivinar que se toca Más; Jürgen pidió destacar o bordear Más). Va con el punto 2 porque es el mismo aviso.

## Qué se pide
1. **Gesto de historias en toda la zona:** tocar a izquierda/derecha y mantener para pausar responde en toda la zona entre las barras de progreso y el botón, no solo sobre el contenido (`TutorialStoryPage.swift`: hoy `onTapGesture` + `onLongPressGesture` van sobre `content(part)` dentro del `ScrollView`). El desplazamiento vertical del contenido largo tiene que seguir funcionando.
2. **«Tus presupuestos/gráficas viven en Más»:** mientras el aviso se ve, la barra de pestañas va desplegada y «Más» queda destacado o bordeado, y se puede tocar para seguir (`PlaceGuide.swift` target `.moreTab`, `PlaceGuideOverlay.swift`, `TabBarArrivesExpandedModifier.swift` / `tabBarMinimizeBehavior`).
3. **Paso 6:** la guía de Estadísticas enfoca bien aunque Más venga desplazado (llevar el elemento a la vista antes de señalarlo) y al terminar devuelve a la persona al Panel (`startChartsStepGuide` en `PanelView.swift`, `chartsStep` y `moreItems` en `PlaceGuide.swift`, `MoreView.swift`).
4. **Intro de Grupos tras cerrar sesión:** si ya se aceptó en Primeros pasos, no vuelve a salir al cerrar sesión y volver a entrar con la misma cuenta (`hasShownGroupsOnboarding` en `AppPreferences.swift` ~559 con `synced: false`, y la limpieza de cerrar sesión en `CloudSignOutFlowLogic.swift` / `DataWipeService.swift`). «Vaciar datos» y «Eliminar cuenta» pueden seguir reiniciándola: decide lo coherente y anótalo en «Decidido sin consultar».

## Qué NO hay que tocar
- Lógica del mazo (qué cuenta como hecho), solo gastos, widget de pagos: ya van en el primer lote.
- Textos de pulido: tercer lote. Oferta Pro y Primeros pasos centrado: esperan maqueta.

## Cómo se sabe que está bien
- Las historias responden al toque en toda la zona, en las intros de los pasos 1 a 5 y en el paso 7.
- El aviso «viven en Más» sale con la barra desplegada y Más destacado; tocar Más sigue la guía.
- Paso 6 con Más desplazado: el foco cae sobre el elemento correcto y al terminar se vuelve al Panel.
- Cerrar sesión y volver a entrar con la misma cuenta no repite la intro de Grupos.
- Pruebas nuevas en `YalaTests/GuiasSenalanBien/` verdes, sin romper las existentes de guías y de cerrar sesión. Al cerrar, mueve a done las 5 cards de arriba.

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

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

1. **Historias, toda la zona:** el contenido del scroll se estira al alto visible (`onScrollGeometryChange` + `minHeight`) y el gesto cuelga de ese marco. El contenido largo sigue desplazándose. Se descarta mover el gesto fuera del `ScrollView` (rompería el desplazamiento vertical).
2. **«Viven en Más»:** la barra queda en `.never` mientras el momento a la vista señala una pestaña (`PlaceGuideCenter.holdsTabBarExpanded`, leído dentro del modificador de la barra, no en `ContentView`). «Más» se bordea con un anillo del acento en una vista de la ventana que no recibe toques (la barra es de UIKit y queda encima de la página). Tocar «Más» sigue la guía como hoy. Vale también para «Grupos» (mismo aviso).
3. **Paso 6:** Más se desplaza hasta la sección que contiene lo señalado (en el orden de la persona) antes de enmarcar; dos intentos (0 y 250 ms). Al terminar con «Entendido» o tocando lo enmarcado: paso hecho y vuelta al Panel. Tocar fuera (cerrar) no cambia de pestaña.
4. **Intro de Grupos tras cerrar sesión:** el borrado del cierre de sesión (que también usa «Eliminar cuenta») conserva solo la marca `hasShownGroupsOnboarding`, como ya sobreviven las intros de Primeros pasos. «Vaciar datos» y «Empezar de cero» del Welcome la siguen reiniciando (otros barridos). Se descarta guardarla por cuenta: más piezas y el teléfono es de quien aprendió.
5. **Textos:** no hace falta ninguno nuevo; no se tocan los `Localizable.strings`.
6. **Cards:** se mueven a done las cinco del encargo al cerrar.
