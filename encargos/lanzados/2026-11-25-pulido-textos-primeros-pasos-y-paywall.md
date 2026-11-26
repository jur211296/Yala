Yala
# Pulido de Primeros pasos y del paywall: selector de moneda, «Presupuesto» chico, nombre cortado, «paso 2 de 3», confeti, título final y texto de precios
---
toca: Yala/App/Views/Onboarding/PrimerosPasos/FirstAccountFlowView.swift,Yala/App/Views/Panel/SetupDeckProgress.swift,Yala/App/Views/Panel/BudgetsWidget.swift,Yala/App/Views/Panel/BudgetWidgetRow.swift,Yala/App/Views/Onboarding/PrimerosPasos/GroupsTutorialFlowView.swift,Yala/App/Views/Panel/SetupChecklistCard.swift,Yala/App/Views/Shared/ConfettiView.swift,Yala/App/Views/Subscription/ProPurchaseComponents.swift,Yala/Utils/L10n+PrimerosPasos23Final.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/PulidoPrimerosPasos,tickets/backlog/2026-11-25-pulido-textos-primeros-pasos-y-paywall.md,tickets/done/2026-11-25-pulido-textos-primeros-pasos-y-paywall.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/guias-y-avisos-senalan-donde-deben
---

Pedido de Jürgen (25-nov, 18:21 Lima): encolar en lotes los hallazgos de la observación en vivo del iPhone 14 (PR #1181, https://github.com/jur211296/Yala/pull/1181). Tercer lote: detalles de texto y de diseño menor. Va después de los dos lotes de bugs porque comparte textos y `SetupChecklistCard.swift`.

## Contexto
- Card del tablero de Yala 2.3: «Pulido de textos de Primeros pasos y del paywall visto en el iPhone 14» (seis puntos, cada uno con captura en la bitácora). Se suma un séptimo de la misma observación.

## Qué se pide
1. **Selector de la segunda moneda** del paso 1: al tocar «+ Añadir moneda» la hoja no dice «Moneda principal» (reutiliza `settings.preferredCurrency`); que diga algo como «Otra moneda». Nombres de moneda en minúscula como en la tarjeta («sol peruano», «dólar estadounidense») en los idiomas donde corresponde (`FirstAccountFlowView.swift`, `FirstAccountCurrencyPicker`).
2. **«Presupuesto» chico** en la fila de pasos del mazo (también «Solo gastos» y «Gastos e ingresos»): que todas las etiquetas salgan al mismo tamaño (palabra más corta, dos líneas o columnas más anchas; elige la que se vea mejor en el iPhone 14 y anótalo) (`SetupDeckProgress.swift`).
3. **Nombre del presupuesto cortado** en el widget del Panel («Mascotas y anima…» con espacio libre): dos líneas o aprovechar el ancho (`BudgetsWidget.swift`, `BudgetWidgetRow.swift`).
4. **Intro de Grupos:** quitar «Grupos · paso 1/2/3 de 3» y usar «Antes de empezar», como las intros de los pasos 1 a 4 (`GroupsTutorialFlowView.swift`).
5. **Confeti** del cierre de Primeros pasos: no tapa el botón «Cerrar» (`SetupChecklistCard.swift`, `ConfettiView.swift`).
6. **Título final:** «¡Primeros pasos completos!» (`pasos23.final.done.title`) se lee raro cuando la mayoría quedó «para después»; cuando hay pasos para después, un título que no diga «completos» (por ejemplo «¡Listo por ahora!»).
7. **Paywall sin precios:** cuando la tienda devuelve la lista vacía, el texto no culpa a la conexión: algo neutro como «Ahora no podemos mostrar los precios. Inténtalo en un rato.» (`ProPurchaseComponents.swift` ~224). En Yala Dev es esperado que no haya precios; no cambies `StoreKitManager`.

## Qué NO hay que tocar
- Lógica del mazo y guías (lotes anteriores). Oferta Pro tras Primeros pasos y Primeros pasos centrado: esperan maqueta de Jürgen.

## Cómo se sabe que está bien
- Los siete puntos corregidos y vistos en el iPhone 14 o en simulador, claro y oscuro, y con texto grande en 2 y 3.
- Pruebas en `YalaTests/PulidoPrimerosPasos/` para lo que tenga lógica (título final según pasos para después, texto con lista vacía).
- Al cerrar, mueve a done la card del pulido.

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

## Paso 0 — decisiones (resueltas en autónomo, bypass, nocturno)

1. **Dónde van los textos nuevos** → tabla propia `PulidoPrimerosPasosPaywall.strings` en los 16 idiomas, no `Localizable.strings`. Motivo: otra rama viva (Novedades 2.3) edita los 16 `Localizable.strings`; una tabla nueva no choca. Molde: `PrimerosPasosPulido.strings`.
2. **Selector de la segunda moneda** → parámetro `title` opcional en `CurrencyPickerSheet` (fuera del `toca:`, cambio de una línea con valor por defecto); el paso 1 pasa «Otra moneda» al añadir o cambiar una moneda que no es la primera. Nombres: se quita el `.capitalized` de la hoja, que deformaba la grafía de cada idioma («Sol Peruano»); cada idioma ya trae su forma correcta (minúscula en es/fr/it/pt/pl/nl, «US dollar» en inglés, «US-Dollar» en alemán). Solo en el selector del paso 1 (parámetro `namesAsWritten`): otros 10 sitios de Ajustes y Grupos fuerzan mayúsculas y cambiar solo la hoja dejaría Ajustes mezclado; va a «Encontrado» para decidirlo para todos.
3. **«Presupuesto» chico** → columnas a la medida de cada etiqueta (fila de siete con huecos iguales, sin encoger texto); si no cabe a lo ancho (iPhone chico o texto grande), 4 columnas en dos filas, como ya hacía con texto de accesibilidad. Descartado: palabra más corta (Pagamentos, Graphiques, Betalingen tienen el mismo problema) y encoger todas por igual (quedan ilegibles).
4. **«Solo gastos» / «Gastos e ingresos» chicos** → no se encontró dónde se encogen: los botones del chat de bienvenida van a todo lo ancho sin reducir texto y ninguna captura lo muestra. Se anota en «Encontrado».
5. **Nombre del presupuesto cortado** → dos líneas en el widget pequeño y en la fila del grande.
6. **Intro de Grupos** → «Antes de empezar», la misma clave que las intros de los pasos 1, 3 y 4.
7. **Confeti** → máscara en la tarjeta: el confeti se desvanece antes de la franja de abajo, donde vive «Cerrar». `ConfettiView` no se toca (otros cinco usos).
8. **Título final** → con algún paso para después, «¡Listo por ahora!»; con los siete hechos, el de siempre.
9. **Paywall sin precios** → texto neutro en los dos casos (lista vacía o error), como propone la bitácora; `StoreKitManager` no se toca.
10. **Dependencia «guías y avisos» (PR abierto, sin mergear)** → no comparte ficheros con este lote; se trabaja sobre `2.3` sin esperarlo.
