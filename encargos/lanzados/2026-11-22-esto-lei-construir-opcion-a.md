Yala
# Rehacer la hoja «Esto leí» con la tarjeta B1 elegida por Jürgen
---
toca: Yala/App/Views/Image/,Yala/App/Views/Voice/,Yala/App/Logic/VoiceEntryFlowLogic.swift,Yala/Utils/L10n.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/EstoLei/,YalaUITests/EstoLei/,tickets/backlog/2026-11-22-esto-lei-construir-opcion-a.md,tickets/done/2026-11-22-esto-lei-construir-opcion-a.md
esfuerzo: high
cierre: cierra-sola
---

El 22-nov Jürgen eligió en el artifact de propuestas (https://claude.ai/artifact/B9FnV4i3hneH9VchcoVW5i; fuentes en `docs/propuestas/2026-11-22-esto-lei/`) la **opción A · Tarjeta B1**. Le dio GO a construirla (decisiones registradas t1886u-4 y widget-t1886s10701). Sus ajustes a las preguntas del artifact:
- «Ver todo» abre el editor B1 de Nuevo registro dentro de la misma hoja, con ‹ para volver: **Sí**.
- La explicación de la cuenta elegida (✦) va en una sola línea: **Sí**.
- El botón principal dice lo que falta: **No**. El botón queda como hoy (Guardar), sin cambiar el texto.

## Qué hacer
Construye la opción A tal como está en el artifact, para foto y para voz, con uno, dos o varios registros y con uno incompleto, en iPhone (claro y oscuro) y en iPad. Reusa los componentes de B1 y de la Bandeja (mismos chips, colores y jerarquía). Nunca un botón debajo de otro. Texto de los botones del toolbar en primary, no índigo. Textos nuevos en todos los Localizable.strings, siempre en español neutro latinoamericano (en es-ES también, sin vosotros).
Si para entrar al editor B1 desde la hoja hace falta tocar archivos fuera del toca, toca lo mínimo y anótalo en el cierre.

## Criterios de aceptación
- La hoja nueva coincide con la maqueta A en todos los casos de arriba (capturas antes y después en el cierre).
- Desde la hoja se completa lo que falta, «Ver todo» abre B1 en la misma hoja y vuelve con ‹, Guardar funciona, «Otra foto» y la voz funcionan, y si cierras sin guardar el registro queda en la Bandeja.
- Tests de la lógica nueva en `YalaTests/EstoLei/`. Gate local en verde.
- PR a 2.3 con auto-merge. Espera el merge real antes de cerrar. Si a los ~45 min la CI sigue roja por algo ajeno al PR, cierra y anótalo.

## Cómo trabajar
- iPhone 14 conectado a la Mini vía DeviceMCP: verifica de verdad que esté libre antes de usar el simulador. En la Max puedes usar un segundo simulador además del de otra sesión.
- Lo menor se decide con la recomendada y se anota. Nada en producción.
- Commits y PR sin firma de IA. No te saltes hooks. Termina con /cerrar-total, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 (decidido al empezar, 22-nov 15:50 Lima)

Fuente: maqueta A del artifact (`docs/propuestas/2026-11-22-esto-lei/index.html`, funciones `A`, `Avarios`,
`editorFull(pushed)` y el recorrido A) + los tres ajustes de Jürgen (d2 Sí, d3 Sí, d1 No).

1. **Un registro:** la tarjeta de «Esto leí» pasa a ser una B1 en pequeño (se reescribe `VoiceDraftReviewCard`, que
   comparten foto y voz): «Ver todo» arriba a la derecha, la descripción centrada (sigue editable al tocarla, como la
   de B1), cápsula de moneda y monto grande, categoría bajo el monto con su puntito (o «● Elige categoría ▾» en ámbar,
   que abre el selector de siempre), la fila Hoy · Cuenta ✦ · # con los chips de B1 (`RecordValueChip`,
   `TagCountChip`, `OneLineChipRow`) y la línea ✦ en UNA línea (d3). Tocar la tarjeta ya no abre nada: lo hace «Ver
   todo». Guardado: la tarjeta queda con «✓ Guardado en <cuenta>» y la hoja se cierra sola como hoy.
2. **Varios:** se conserva la vista de hoy (total, barra, días, filas con marca). La fila deja de abrir el formulario
   al tocarla: se despliega (chips de lo que falta, fecha, cuenta y «Ver todo»); la primera marcada a la que le falta
   algo sale desplegada sola. El recuento suma «· N por completar» en ámbar.
3. **«Ver todo»** empuja dentro de la misma hoja el editor B1 de la Bandeja (`InboxDraftEditSheet`) con ‹ para volver
   (d2). Es el único fichero fuera del `toca` que hace falta: un modo «empujado» (‹ en vez de X, sin «Aprobar luego»,
   y sus cierres vuelven a lo leído en vez de cerrar la hoja). ‹ guarda lo editado en el borrador.
4. **Botón principal:** «Guardar» como hoy, apagado si falta algo (d1 No). Nunca un botón debajo de otro: con texto
   grande, «Otra foto» se queda en su icono al lado de «Guardar», que encoge su texto en una línea.
5. **Barra:** X a la izquierda, título al centro y, a la derecha, las fotos (foto) o un botón de micro que enseña lo
   que dijiste (voz). Sin textos en índigo.
6. **«Otra foto» / «Otra vez» suman** a lo leído en vez de descartarlo (recorrido A, paso 4): ya no hay nada que
   borrar, así que deja de preguntar (sustituye a la decisión 81 de la revisión 2.3 en esta hoja). Desde «Elegir» o
   escuchando, ‹ vuelve a lo leído.
7. **Cerrar sin guardar:** lo leído queda en la Bandeja (como hoy) y, al cerrar, un aviso «Lo que leí quedó en tu
   Bandeja · Ver» (recorrido A, paso 5), con el aviso global que ya existe (`DraftDiscardUndoNotice`).
8. Textos nuevos en los 17 `Localizable.strings`, español neutro también en es-ES. Lógica pura nueva en
   `VoiceEntryFlowLogic`/`MultiDraftReviewLogic` con tests en `YalaTests/EstoLei/`; capturas y recorrido con XCUITest en
   `YalaUITests/EstoLei/`. Los XCUITest viejos que fijaban «tocar la fila abre el formulario» y «Otra foto pregunta
   antes de borrar» se actualizan a lo nuevo.

Asumido sin preguntar: el aviso del paso 7 sale también por deslizar la hoja hacia abajo (no solo con la X); la
necesidad (Necesario/Opcional) en la tarjeta es solo texto, se cambia en «Ver todo»; el monto se corrige en «Ver
todo» (la tarjeta no tiene teclado).
