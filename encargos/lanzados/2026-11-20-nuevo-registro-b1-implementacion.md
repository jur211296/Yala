Yala
# Nuevo registro: la hoja B1 con chips en una sola fila y la pantalla de éxito minimalista
---
toca: Yala/App/Views/Transactions/,YalaTests/NuevoRegistroB1/,tickets/backlog/2026-11-19-nuevo-registro-b-realista-maquetas.md,tickets/done/2026-11-19-nuevo-registro-b-realista-maquetas.md,tickets/backlog/2026-11-19-nuevo-registro-limpio-maquetas.md,tickets/done/2026-11-19-nuevo-registro-limpio-maquetas.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Jürgen eligió el 20-nov a las 06:14 la hoja **B1** y la pantalla de éxito **minimalista** de las maquetas de la segunda ronda (https://claude.ai/artifact/8Se8XnuPMGBg1gHsnC7SRD). La especificación está en `tickets/backlog/2026-11-19-nuevo-registro-b-realista-maquetas.md`: léela entera, incluido el inventario de lo que se mueve y los riesgos (accesibilidad, Siri, atajos, widgets y pruebas). Un PR y un cierre.

## Ajustes de Jürgen sobre B1 (mandan sobre la especificación)
1. **Los chips de abajo van siempre en una sola fila.** Nunca generan una segunda fila por sí solos. Las etiquetas se muestran como «#2» (número) y nada más. Si se llega al ancho, se trunca un poco el nombre de la cuenta. Pruébalo con nombres largos, varias etiquetas, el tamaño de texto grande y el iPhone SE.
2. **Transferencias:** la fecha pasa al lugar donde iría la categoría, y la fila de chips queda solo para las dos cuentas, con más espacio. También en una sola fila, truncando nombres si hace falta.
3. **Pantalla de éxito minimalista:** la descripción va suelta debajo del monto. Después, los campos en este orden de importancia: fecha, cuenta, subcategoría, naturaleza y etiqueta (solo si tiene).

4. **Sugerencias al escribir la descripción** (los chips que salen al teclear, como «SmartFit J1», «SmartFit J2»; Jürgen las aprueba como están). Al elegir una, si los registros anteriores con esa descripción tuvieron la misma cuenta, y la misma subcategoría o la misma etiqueta, se asignan también automáticamente, no solo el nombre. Si los anteriores no coinciden entre sí en alguno de esos datos, ese dato no se toca. Lo que el usuario ya eligió a mano en este registro no se pisa. Está en `DescriptionAutocomplete.swift`. Agrega un test para cada caso.

Textos nuevos en su propia tabla y en español neutro latinoamericano.
Card: «Nuevo registro: hoja B1 con chips en una fila y éxito minimalista». Tests en `YalaTests/NuevoRegistroB1/`. El artifact muestra la hoja de hoy al lado de la nueva (gasto, ingreso y transferencia, con nombres largos y etiquetas) y la pantalla de éxito, en claro y oscuro, en el iPhone 17 Pro y el SE.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (resuelto por la sesión, semi, 2026-11-20)

Medido antes de decidir:
- La decisión del artifact de la ronda 2 no se puede leer desde esta cuenta (artifact de otra organización). Manda el encargo: hoja B1 + éxito minimalista; lo demás, con la opción recomendada de la ficha (favoritos se pliegan con teclado).
- Las sugerencias «SmartFit J1» NO viven en `DescriptionAutocomplete.swift` (eso son las menciones # ! @): viven en `DescriptionSuggestionLogic` + `NewTransactionViewModel.applyDescriptionSuggestion`. El autocompletado de datos va ahí.
- La pantalla de éxito completa solo sale en los 3 primeros registros (`TransactionSaveFeedbackLogic`); después el formulario cierra con aviso. No se cambia.
- «Hacer recurrente» hoy guarda el registro y cierra al elegir la frecuencia: nunca hay un «recurrente activo» sin guardar. Se conserva (la ficha dice «no cambia qué se guarda ni cómo»): no hay línea «↻ Cada mes» en el formulario y el punto de «···» sale solo con Mi parte.
- Las pruebas de interfaz no corren en el CI del PR (solo el gate local, techo 30 min): las 22 suites que usan los controles que se mueven se migran por código y se corre el subconjunto central.

Decisiones:
1. Ajustes de Jürgen mandan: fila de abajo SIEMPRE en una línea (también con texto grande); etiquetas «#2»; si no cabe, trunca la cuenta. Transferencia: la fecha va bajo el monto (sitio de la categoría) y la fila es Origen · Destino, en una línea, truncando.
2. Autocompletar al elegir una sugerencia: por dato y por separado (cuenta, subcategoría, conjunto de etiquetas), solo si TODOS los registros anteriores con esa descripción (mismo lado) coinciden. «Elegido a mano» = distinto de lo precargado al abrir el formulario: la cuenta por defecto se puede cambiar; una subcategoría o etiquetas ya puestas no. Solo en un registro nuevo (al editar, solo el nombre).
3. Cápsula de moneda: menú con las monedas de las cuentas activas y cuántas tiene cada una; elegir una pasa a la línea de la tarjeta en esa moneda o a la primera cuenta en esa moneda. Con una sola moneda no abre nada. El selector de cuenta NO se filtra (hoy no lo hace y filtrar quitaría opciones). Las pastillas PEN/USD de la tarjeta salen.
4. «Agregar otro»: guarda, vibra, aviso «Gasto guardado» y deja la hoja vacía con el mismo tipo, cuenta, moneda y fecha. Solo en un registro nuevo.
5. Éxito: Favorito y Recurrente abren las hojas de hoy; Favorito queda «En favoritos» al guardar.
6. Identificadores de accesibilidad de siempre donde el control sigue existiendo (cuenta, subcategoría, etiquetas, Guardar, éxito); los que se mueven a menús conservan su id dentro del menú.

Ajustes de Jürgen en la sesión (20-nov, sobre las capturas): cuenta y «#» neutros con solo el icono en color (opción recomendada que eligió en la pregunta), en transferencia «Hoy» sobre la descripción, y en el éxito la descripción sobre el monto.
