Yala
# Textos: «Partes iguales» en el éxito de un gasto de grupo, VoiceOver de «y dividido…» y la ayuda «Toca una burbuja»
---
toca: Yala/App/Views/Groups/GroupExpenseSuccessView.swift,Yala/App/Views/Groups/GroupExpenseFormView.swift,Yala/App/Logic/GruposPulidoDivisionDetalle,Yala/Resources/de.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/en-GB.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/en.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es-419.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es-AR.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es-ES.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/fr.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/it.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/ja.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/nl.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pl.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pt-BR.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pt-PT.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pt.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/zh-Hans.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/TextosRepartoYAyuda,tickets/backlog/2026-11-27-textos-reparto-y-ayuda-distribucion.md,tickets/done/2026-11-27-textos-reparto-y-ayuda-distribucion.md
modelo: opus
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/trabas-flujo-proyeccion-y-convertir-a-compartido
---

Decisión de Jürgen (27-nov, 06:17 Lima): aprobó encolar tal cual los tres lotes propuestos a partir de los hallazgos de los cierres del 26-nov y de los pendientes de 2.3. Espera a «Trabas: proyección inteligente…», que también toca `GroupExpenseFormView.swift`.

## Contexto
- Cards del tablero de Yala 2.3 (búscalas por título con `tablero listar --proyecto Yala`): «Textos de reparto y ayuda de Distribución: «Partes iguales» en el éxito, VoiceOver de «y dividido…» y «Toca una burbuja»». Al terminar, muévela a «in qa» con una nota del PR.

## Qué se pide
1. **Éxito al guardar un gasto de grupo** (`GroupExpenseSuccessView.swift`): dice «Partes iguales» en un «es todo de…». Usa la misma función que ya arregló el detalle (`Yala/App/Logic/GruposPulidoDivisionDetalle/GroupSplitLabelLogic.swift`, PR 1195), con pruebas de los casos.
2. **VoiceOver de «y dividido…»** en el formulario de gasto de grupo (`GroupExpenseFormView.swift`): lee el tipo guardado y no el reparto real; que use la misma función.
3. **Ayuda «?» de las gráficas de reparto** (claves `panel.widgetInfo.categoriesPie/subcategoriesPie/tagsPie.smallHowA` y `largeHowA` en `Localizable.strings`, y la ayuda de Distribución en Estadísticas si usa las mismas): dicen «Toca una burbuja para filtrar…», pero en 2.3 tocar una categoría abre su detalle (y filtra la subcategoría). Comprueba en la app qué hace cada toque hoy y reescribe solo esas claves, en los 16 idiomas con traducción real. Si la ayuda de Distribución vive en otro archivo fuera de `toca:`, anótalo.
- Textos nuevos, si hacen falta, en `GruposPulidoDivisionDetalle.strings`; en `Localizable.strings` solo se reescriben esas claves.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio de código con su prueba en la carpeta de pruebas de este encargo.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Puedes usar un segundo simulador en la Max; en la Mini, uno solo. Apaga lo que enciendas.
- **iPhone 14** («iPhone de JURGEN», conectado a la Max) por DeviceMCP: tiene candado (ADR-132 de casa, hook `candado_dispositivo.py`). Si al usarlo te dice que está ocupado por otra sesión, **no reintentes en bucle**: sigue con el simulador o con otra parte del trabajo y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Sin cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Nada fuera de `toca:`. Este lote corre en paralelo con otros que tienen archivos vecinos: si necesitas otro archivo, no lo toques; anótalo en «Saltado o asumido sin preguntar» con el motivo.

## Cierre
- Capturas antes/después de los tres textos (y la lectura de VoiceOver) en un **artifact visual de Claude** enlazado en el cierre (ADR-130 de casa).
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión lanzada, modo semi): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir: el PR del que depende («Trabas: proyección inteligente…») no toca `GroupExpenseFormView.swift` ni nada de este `toca:`. En el Panel, tocar una burbuja, porción o fila de cualquiera de las tres tortas filtra («ver solo»; tocar otra vez lo quita; con algo oculto pregunta «Ver solo / Ocultar»). En Distribución, la torta de categorías abre el detalle de la categoría y las de subcategorías y etiquetas filtran igual que el Panel. La hoja «?» es la MISMA en los dos sitios (`WidgetInfoButton(kind:)`), y fuera del Panel enseña la versión `small`, así que las seis claves se leen en el Panel y en Distribución.

**D1 · ¿Qué dice la ayuda de categorías, que se ve en dos pantallas con dos conductas?** → Las dos, por pantalla: «En el Panel, ver solo esa categoría; otra vez para volver a verlo todo. En Distribución, abre el detalle». Por qué: un solo texto tiene que ser verdad en los dos sitios. Alternativa descartada: que la hoja sepa desde dónde se abre (toca `WidgetInfoContent`/`WidgetInfoButton`, fuera de `toca:`).

**D2 · ¿La ayuda menciona la pregunta «Ver solo / Ocultar» con algo oculto?** → No. Por qué: es el caso raro y la propia hoja lo explica al salir; alargaba el texto. Alternativa descartada: una frase más en las seis claves.

**D3 · Icono de la fila «Reparto» del éxito.** → Si el reparto es de una sola persona, `person.fill` (el del detalle); en el resto, el icono de su tipo como hasta ahora. Por qué: «Todo de Pia» con el icono de dos personas se contradice; el resto no cambia a la vista. Alternativa descartada: pasar todos al icono del detalle (cambiaba «Partes iguales» sin que nadie lo pidiera).

**D4 · ¿Se cambia también el texto VISIBLE de «y dividido [en partes iguales]» del formulario?** → No: solo lo que lee VoiceOver, como pide el encargo. Por qué: el visible es la pastilla que abre el editor y Jürgen no lo pidió. Se anota en «Encontrado». Igual para la frase entera del grupo de 2 (su lectura es el texto visible).

**D5 · Pruebas de interfaz.** → No se añade un XCUITest: `YalaUITests/` no está en `toca:`. Las pruebas van a `YalaTests/TextosRepartoYAyuda/` (lógica, cableado y textos de los 16 idiomas) y las capturas se sacan conduciendo el simulador. El gate corre los XCUITest existentes de las áreas tocadas.

**D6 · Dónde vive la función nueva.** → En `Yala/App/Logic/GruposPulidoDivisionDetalle/` (extensión de `GroupExpenseSuccessData` y un `splitLabel(splitType:shares:currentMemberID:name:)` en `GruposPulidoDivisionDetalleText`). Por qué: está en `toca:` y es la carpeta de la función que ya arregló el detalle. Sin claves nuevas: «Todo tuyo», «Todo de %@» y «Personalizado» ya existen.

**D7 · es-AR.** → Voseo («Tocá», «tocala», «Mantené pulsada»), como pide `l10n.md` para las variantes; el texto viejo estaba en tuteo.
