Yala
# Editor de la Bandeja con chip de grupo y recurrente en el menú, y texto de los botones del toolbar en primary en toda la app
---
toca: Yala/App/Views/,Yala/App/Components/,Yala/App/DesignSystem/,Yala/App/Theme/,Yala/Resources/,Yala/Utils/L10n.swift,Yala/Utils/L10n+RecurrenteDesdeRegistro.swift,YalaTests/BandejaChipGrupoToolbar/,tickets/backlog/2026-11-22-bandeja-editor-chip-grupo-toolbar-primary.md,tickets/done/2026-11-22-bandeja-editor-chip-grupo-toolbar-primary.md
esfuerzo: high
cierre: cierra-sola
---

Lote de dos pedidos de Jürgen del 22-nov (Lima), ya registrados como decisiones t1875u y t1876u. GO de Jürgen en el chat al pedirlos.

## 1. Editor de registro de la Bandeja («Editar gasto», `Yala/App/Views/Inbox/InboxDraftEditSheet.swift`) · t1875u
Hoy, debajo de «Dejar para después» y «Guardar», hay dos enlaces: «Guardar y hacer recurrente» y «Convertir a gasto compartido». Jürgen quiere limpiar esa zona:
- «Guardar y hacer recurrente» pasa al menú «…» de arriba a la derecha, con el mismo comportamiento de hoy.
- «Convertir a gasto compartido» se reemplaza por un CHIP DE GRUPO en la fila de chips de abajo (junto a la fecha, la cuenta y «#»), con el ícono de grupo. Al tocarlo se elige el grupo (con el mismo flujo de convertir a compartido que existe hoy); una vez elegido, el chip muestra el nombre del grupo. Que la fila siga cabiendo en iPhone chico (si no cabe, el chip muestra solo el ícono).
- Abajo quedan solo «Dejar para después» y «Guardar».
- Revisa si las otras pantallas de registro con el rediseño B1 (Nuevo registro, Nuevo registro de Grupos, aprobación de la Bandeja) tienen los mismos dos enlaces; si los tienen, aplica lo mismo para que queden iguales, y anótalo.

## 2. Texto de los botones del toolbar en primary · t1876u
El texto de los botones con texto del toolbar (por ejemplo «Editar» en la hoja de cuenta del Panel) hoy sale en índigo. Debe ir en color primary (el color de texto principal del tema, claro y oscuro). Barrido en TODA la app: todos los botones con texto del toolbar iguales. Los botones de solo ícono y los botones de acción principal fuera del toolbar no cambian.
- Si existe un estilo o componente común de botón de toolbar, arréglalo ahí; si no, créalo en el sistema de diseño y migra los usos, en vez de parchar cada pantalla.
- Deja una prueba o regla que evite que vuelva el índigo en el toolbar (por ejemplo en `.claude/rules/swiftui-ds.md`, anotado en el cierre).

## Criterios de aceptación
- El editor de la Bandeja muestra solo los dos botones abajo, el chip de grupo en la fila y «Guardar y hacer recurrente» en el menú «…», funcionando.
- Ningún botón con texto del toolbar queda en índigo, en claro y oscuro, iPhone y iPad.
- Capturas antes y después de las pantallas tocadas.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): conectado a la Mini para cualquier sesión vía DeviceMCP; verifica de verdad si está libre antes de usarlo y suéltalo al terminar. En la Max puedes usar un segundo simulador además del de otra sesión. No uses `-derivedDataPath /tmp/claude-*`.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- Nada en producción (ni CloudKit ni Supabase).
- Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, tras `git rebase origin/2.3`, por fila, sin pisar lo de otra sesión.
- Commit y PR sin firma de IA, contra 2.3. Auto-merge activado; no cierres hasta ver el PR dentro de 2.3. Si el CI falla por tu PR, arréglalo. Si tras unos 45 minutos sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) checkpoint recuperable y card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude con capturas, nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (semi, sin nadie mirando): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Qué hace el chip de grupo al tocarlo** → abre un menú con los grupos donde se puede apuntar el gasto (y «Sin grupo» cuando ya hay uno elegido); el chip pasa a decir el nombre del grupo. Al tocar «Guardar» con un grupo elegido sigue el flujo de hoy de convertir a compartido, ya con ese grupo: se abre el formulario del gasto de grupo prellenado.
Por qué: el encargo pide que el chip muestre el nombre una vez elegido, y eso solo es posible si la elección vive en el editor. Alternativa descartada: que el chip dispare el flujo de hoy en el acto (cerrar el editor y abrir el selector), porque el chip nunca llegaría a enseñar el grupo.

**D2 · Menú o la hoja «Elegir grupo» de hoy** → menú.
Por qué: es una lista corta, no apila una hoja sobre otra (los XCUITest de hoy dicen que esa hoja sobre hoja no se toca de forma estable) y deja quitar el grupo con «Sin grupo». Alternativa descartada: la hoja `GroupPickerSheet`, que no tiene forma de volver a «sin grupo».

**D3 · Cuándo sale el chip** → en los mismos casos que salía «Convertir a gasto compartido», sin exigir el monto escrito; y siempre que ya haya un grupo elegido.
Por qué: un chip que aparece al escribir el primer dígito mueve la fila entera. «Guardar» sigue pidiendo el monto.

**D4 · Qué pide «Guardar» con grupo elegido** → solo el monto: la cuenta y la categoría se eligen en el gasto de grupo, como en el flujo de hoy.

**D5 · «Guardar y hacer recurrente» con grupo elegido** → no se ofrece en el menú «…» mientras haya grupo; sin grupo, el mismo comportamiento de hoy (apagado si falta algo).
Por qué: un gasto de grupo no se guarda como registro personal recurrente.

**D6 · Chip en iPhone chico** → sin grupo elegido, si «Grupo» no cabe, el chip enseña solo el ícono. Con grupo elegido enseña su nombre y, si no cabe, encoge junto con la cuenta (truncan los dos).
Por qué: medido en el iPhone 17 Pro, «Hoy · Cuenta Principal · # · Grupo» ya no cabe; con solo ícono el grupo elegido no se vería nunca, y el encargo pide que el chip lo diga.

**D7 · Otras pantallas B1** → solo el editor de la Bandeja tiene los dos enlaces. Nuevo registro al editar tiene solo «Convertir a gasto compartido» (con estados apagados y su explicación) y ya llevaba el recurrente en «···»; Nuevo registro de Grupos y las aprobaciones de gasto de grupo no tienen ninguno. No se tocan; se anota en el cierre.

**D8 · Texto del toolbar en primary: dónde se arregla** → componente nuevo `YalaToolbarTextButton` junto a `YalaToolbarButton` (texto con tinte primary), y migración de todos los botones de texto de barra. Más un source-scan que falle si vuelve un botón de texto crudo dentro de un `ToolbarItem`, y una línea en `.claude/rules/swiftui-ds.md`.
Por qué: el encargo lo pide así si no hay componente común; hoy cada pantalla lo parchea (la Bandeja pone `.tint(.primary)` a toda la vista). Alternativa descartada: apariencia global de UIKit, que no se puede fijar con un test y tocaría también los botones de ícono.

**D9 · «Seleccionar» de Registros, que hoy va en índigo a propósito** → pasa a primary como todos.
Por qué: el encargo dice «todos los botones con texto del toolbar iguales».

**D10 · Botones de confirmación con texto (`.confirmationAction`)** → mismos criterios: texto en primary. Si iOS los pinta como cápsula rellena, se mide y se anota antes de cambiarlos.
