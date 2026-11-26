Yala
# Grupos: pulido de «¿Cómo se dividió?», detalle de gasto y bug «Partes iguales»
---
toca: Yala/App/Views/Groups/GroupTwoPersonSplitView.swift,Yala/App/Views/Groups/GroupExpenseDetailSheet.swift,Yala/App/Logic/TwoPersonSplitOptions.swift,Yala/App/Logic/TwoPersonSplitOptions+Text.swift,Yala/App/Logic/GruposPulidoDivisionDetalle,Yala/Resources/de.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/en-GB.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/en.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es-419.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es-AR.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es-ES.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/es.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/fr.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/it.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/ja.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/nl.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pl.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pt-BR.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pt-PT.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/pt.lproj/GruposPulidoDivisionDetalle.strings,Yala/Resources/zh-Hans.lproj/GruposPulidoDivisionDetalle.strings,YalaTests/GruposPulidoDivisionDetalle,YalaUITests/GruposPulidoDivisionDetalle,tickets/backlog/2026-11-26-grupos-pulido-division-y-detalle-gasto.md,tickets/done/2026-11-26-grupos-pulido-division-y-detalle-gasto.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
---

Pedido de Jürgen (26-nov, 13:31 Lima), con 5 capturas: «la pantalla para elegir la división, cuando son dos personas, está un poco fea, y creo que podría ser un detent medium, porque solo tiene cuatro opciones, y ser un poquito más amigable. […] cómo se ve cuando aprieta un registro de grupo en detent medium y en large. En medium quisiera que se vea más como agrupadas las cosas y más fácil de ver, más rápido, porque ahorita como que fuerza al detent large. Te mando un ejemplo de cómo se ve ahorita en los registros personales, y también el detent large no va nada con el resto de la app, o sea, no está como en cards […] todo está plano. Y además veo errores como por ejemplo dice en partes iguales, pero en verdad no fue en partes iguales, todo fue para Pia.»

## Capturas de referencia (míralas antes de empezar)
En `~/Claude/flota/referencias/grupos-division-y-detalle/` (están en la Mini y en la Max, misma ruta):
- `01-como-se-dividio-2-personas.png`: la hoja «¿Cómo se dividió?» de un grupo de 2 abierta en grande con solo «Pagaste · partes iguales», «Pagaste · es todo de Pia», «Pagó Pia · partes iguales», «Pagó Pia · es todo tuyo» y «Más opciones»; media pantalla vacía.
- `02-detalle-grupo-medium.png`: detalle de un gasto de grupo en media altura; la tarjeta de Reparto se corta y obliga a subir.
- `03-detalle-grupo-large-bug-partes-iguales.png`: el mismo detalle en altura completa, plano sobre fondo oscuro, sin tarjetas, y con «Partes iguales» junto a «Reparto» aunque fue «Pagaste · es todo de Pia» (Tú S/ 0.00, Pia S/ 214.00).
- `04-ref-detalle-personal-medium.png`: **referencia**: el detalle de un registro personal, que cabe limpio en media altura, agrupado en tarjetas.
- `05-ref-editar-gasto-personal.png`: referencia del estilo de tarjetas del registro personal.
Card del tablero de Yala 2.3 (búscala por título con `tablero listar --proyecto Yala`): «Grupos: pulido de «¿Cómo se dividió?», detalle de gasto en cards y bug «Partes iguales» (2.3)». Al terminar, muévela a done con su «hecha cuando» cumplido.

## Qué se pide
1. **«¿Cómo se dividió?» (grupos de 2)** (`GroupTwoPersonSplitView.swift`, opciones en `TwoPersonSplitOptions.swift` / `+Text.swift`): que abra en media altura, o ajustada al contenido sin desperdiciar media pantalla vacía, y más amigable y cuidada: las cuatro opciones claras de un vistazo (quién pagó y cómo se reparte), «Más opciones» como hoy (cierra la hoja y abre el reparto completo del formulario). Respeta Dynamic Type grande: si no cabe, que pueda subir a grande.
2. **Detalle de gasto de grupo en media altura** (`GroupExpenseDetailSheet.swift`): más compacto y agrupado, al estilo del detalle de registros personales (captura 04): lo importante (importe, quién pagó, reparto con lo de cada uno) visible sin subir; lo secundario más abajo.
3. **Detalle en altura completa:** con las mismas tarjetas que en media altura, consistente con el resto de la app (sin quedar plano sobre el fondo). Claro y oscuro.
4. **Bug de la etiqueta de reparto:** hoy `splitTypeLabel` en `GroupExpenseDetailSheet` cae en «Partes iguales» para todo lo que no es porcentaje, exacto o partes, y un «es todo de Pia» sale como «Partes iguales». Saca la lógica de la etiqueta (y su icono) a una función pura en `Yala/App/Logic/GruposPulidoDivisionDetalle/` que mire el tipo y los montos reales del reparto, y cúbrela con pruebas unitarias en `YalaTests/GruposPulidoDivisionDetalle/` para todos los casos: partes iguales entre 2 y entre varios, todo de una persona (otra persona o yo), «pagó X · es todo tuyo», montos exactos, porcentajes, partes, céntimos que no dividen exacto, y gastos viejos sin tipo guardado. Revisa si la misma etiqueta equivocada sale en otro lugar que use esta vista y anótalo si queda fuera de `toca:`.
- Las alturas de las hojas se ponen **dentro** de `GroupTwoPersonSplitView` y `GroupExpenseDetailSheet` (los que las presentan, `GroupExpenseFormView.swift` y `GroupDetailView.swift`, hoy no les ponen altura y están reservados por otras sesiones encoladas: no los toques). Usa los helpers de la app para alturas (`yalaSheetDetents`) como el resto de las hojas.
- Textos nuevos solo en la tabla `GruposPulidoDivisionDetalle.strings` de cada uno de los 16 `.lproj`, con traducción real, nunca en `Localizable.strings`.
- No cambies cifras, reglas de reparto ni datos guardados: es vista y etiqueta.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y el detalle de registro personal en el código para copiar su estilo de tarjetas.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Puedes usar un segundo simulador en la Max o el iPhone 14 («iPhone de JURGEN», conectado a la Max) por DeviceMCP para probar y capturar; en la Mini, un solo simulador. Comprueba antes que el iPhone no esté bloqueado; si lo está, sigue con el simulador y anótalo. Apaga lo que enciendas. No borres datos del iPhone.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Nada fuera de `toca:`; si necesitas otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.

## Cierre
- Capturas antes/después de las tres pantallas (hoja de división, detalle en media y en altura completa; claro y oscuro, iPhone 14 o simulador) en `capturas/` del worktree, y un **artifact visual de Claude** con el antes/después junto a las capturas de Jürgen, enlazado en el cierre. No Markdown, PDF ni documento de puro texto.
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», las capturas y el link del artifact. `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: todas menores y reversibles)

1. **Etiqueta de reparto: mandan los montos, no solo el tipo.** Una sola persona con parte → «Todo tuyo» / «Todo de X», sea cual sea el tipo guardado. Varias con la misma parte (tolerancia 1,5 céntimos) → «Partes iguales». Varias con partes distintas → el tipo guardado (porcentaje, monto exacto, proporciones) o «Personalizado» si el tipo es `equal`, vacío o desconocido. Sin partes cargadas → el tipo guardado como antes.
2. **La barra de proporciones** sigue el mismo criterio (solo si las partes son distintas), en vez de mirar solo el tipo guardado. Es vista: no cambia cifras.
3. **«¿Cómo se dividió?»**: rejilla 2×2 de tarjetas (filas = quién pagó, columnas = partes iguales / es todo de uno) con el saldo de cada opción; abre a media altura y sube a grande con texto de accesibilidad (abre ya en grande). La etiqueta de accesibilidad de cada opción no cambia («Pagó Caro · partes iguales. …»), para no romper VoiceOver ni el XCUITest de Grupos.
4. **Detalle de gasto**: cabecera compacta como el registro personal (icono + importe en línea, descripción · fecha debajo); una tarjeta con «Tu parte» arriba y el reparto debajo; otra con categoría, nota y «En tus finanzas». Alturas `[.medium, .large]` con selección: a media altura, el cristal del sistema; en grande, fondo `.subtle` para que las tarjetas se despeguen (era el «todo plano»).
5. **Textos nuevos** en la tabla `GruposPulidoDivisionDetalle.strings`, con su lector en `Yala/App/Logic/GruposPulidoDivisionDetalle/` (dentro de `toca:`), no en `Yala/Utils/`.
