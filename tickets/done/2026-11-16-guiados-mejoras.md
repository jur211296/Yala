---
id: 2026-11-16-guiados-mejoras
status: done
priority: high
area: ai
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-guiados-mejoras (Jürgen, 16-nov 17:39 Lima)
---
# Guiados de Yala IA: subcategorías, opciones avanzadas y los casos que faltaban

Jürgen (16-nov): los guiados de presupuesto y de pago planificado del PR anterior trabajan con categorías, no preguntan
lo avanzado de los editores, no hacen presupuestos de una sola vez ni pagos «cada N», no entienden montos dichos con
palabras y el saludo de Yala IA no los menciona.

## Paso 0 — decisiones (sesión nocturna, resueltas en autónomo; ninguna vital)

**Medido antes de decidir** (editores en `Yala/App/Views/Planning/`):

- Presupuesto (`BudgetEditorView`): nombre, tope, moneda, período (con «una sola vez» y fechas), activo, avisos
  (umbrales 50/75/90/100 y personalizado), cuentas, subcategorías, etiquetas, necesidad, «incluir tu parte de los
  gastos de grupo» (solo con grupos) y «mostrar en el widget».
- Pago (`ScheduledPaymentEditorView`): nombre, monto, nota, gasto o ingreso, suscripción, logo, cuenta, subcategoría,
  etiquetas, necesidad, recurrencia con intervalo («cada N»), fecha de fin, aviso, monto variable, activo y gasto de
  grupo (reparto entre miembros).

**Decidido:**

1. **Subcategorías siempre.** Presupuesto: tras elegir categorías, una pregunta nueva con las subcategorías de cada
   una, todas marcadas, que se pueden quitar (la pieza de Primeros pasos sale a `TutorialQuestionPieces` y la usan los
   dos). Si la frase nombra una subcategoría («taxi»), solo esa queda marcada y la pregunta no se repite. Pago: ya
   guardaba una subcategoría; ahora la frase también la rellena («la luz»). El paso vive en el motor como
   `.subcategories`, para los guiados que vengan.
2. **Opciones avanzadas.** Antes de «Revisa antes de crear»: «¿Quieres revisar las opciones avanzadas? Puedes seguir
   sin eso». No → se crea con los valores de hoy. Sí → una a una, cada una con «Saltar» (saltar = el valor de hoy).
   - Presupuesto: nombre, avisos (75 % y 100 % · solo al 100 % · sin avisos), solo algunas cuentas, etiquetas (si
     hay), tu parte de los gastos de grupo (si hay grupos) y mostrarlo en el widget del Panel.
   - Pago: ¿es una suscripción?, aviso (3 días antes · 1 día antes · el mismo día · sin aviso), hasta cuándo (solo si
     se repite), nota y etiquetas (si hay).
   - Elegir un aviso pide el permiso de notificaciones como Primeros pasos; sin avanzadas no se pide nada, como hoy.
   - **Fuera, con motivo:** el gasto de grupo del pago (reparto entre miembros: es el puente de Grupos, donde un error
     sale caro; ticket en backlog), el filtro por necesidad (raro de usar, una pregunta más), gasto o ingreso
     (cambiaría las categorías ya elegidas) y el logo (sale solo con la marca).
3. **Una sola vez y cada N.** Presupuesto: «Una sola vez» como cuarto período, con fechas de inicio y fin. Pago: en
   «¿Cada cuánto?», una fila «Cada N días / semanas / meses». La frase los rellena («cada 2 semanas», «cada 15 días»,
   «una sola vez»).
4. **Montos con palabras** en español, inglés y portugués: las palabras se pasan a cifras antes de leer la frase
   («mil quinientos» → 1500, «dos mil cincuenta soles» → 2050 PEN, «el cinco de cada mes» → día 5). «Un», «una»,
   «a», «one», «um» sueltos no cuentan como 1. En los demás idiomas se pregunta el monto como hoy.
5. **Saludo.** «Hola, soy Yala IA. Puedo ayudarte con esto:» y una tercera ficha, «Crea conversando», con dos atajos
   tocables que abren el guiado sin pasar por el servidor. No sale en la prueba de cortesía de Primeros pasos ni sin
   conexión (allí el saludo es otro).
6. **Voz en el iPhone 14** con Device MCP, siguiendo el guion de `tickets/qa/2026-11-15-ia-guiados.md`.

## Decidido sin consultar (ficheros fuera del `toca:`)

- `FirstBudgetFlowView.swift` usa la pieza de subcategoría movida a `TutorialQuestionPieces`: mismo aspecto, sin
  duplicar.
- `ChatGreetingBubble.swift`: la ficha nueva del saludo.
- `qa/coverage-index.json`: el área `yala-ia-guiados` al día.
- `ChatSheetView.swift`: al abrirse o avanzar un guiado se cierra el teclado del chat (tapaba la tarjeta), y un pedido
  de guiado ya no pide el permiso del camino ampliado de la nube (`ChatAssistantViewModel.sendQuestion`).

## Qué se hizo

- **Motor** (`ChatGuidedEngine`): pasos `.subcategories`, `.dates`, `.advanced` y las doce opciones avanzadas; «Atrás»
  salta lo que ya no se pregunta; una opción avanzada sin «Sí» no se contesta; progreso solo con lo que se pregunta.
- **Respuestas** (`ChatGuidedFlow`): campos nuevos opcionales (las sesiones del día de la versión anterior se siguen
  leyendo). «Una sola vez» como período; «cada día» y `interval` en el pago.
- **Frase** (`ChatGuidedIntentDetector` + `ChatGuidedNumberWords`): números con palabras en es, en y pt; «cada N
  días/semanas/meses», «quincenal», «todos los días»; «una sola vez» (y «una vez al mes» sigue siendo mensual); la
  subcategoría por su nombre en el presupuesto y por sus palabras del día a día en el pago; «2 semanas» o «para los dos»
  no son el monto.
- **Guardado** (`ChatGuidedCreator`): fechas del presupuesto de una sola vez, cuentas (las del editor de presupuestos),
  etiquetas, avisos, gastos de grupo y widget; intervalo, inicio de «cada N días», fecha de fin, aviso y nota del pago.
- **Tarjeta** (`ChatGuidedFlowCard`): las preguntas nuevas, «Saltar», las filas nuevas en «Revisa antes de crear».
- **Saludo** (`ChatGreetingBubble`): «Puedo ayudarte con esto:» y la ficha «Crea conversando».
- **Textos**: 65 claves nuevas `iaGuided.*` en los 16 idiomas.

## Pruebas

- `YalaTests` entero: 14.554 tests en 1.708 suites; un rojo de idiomas («Panel» en italiano y neerlandés) arreglado y
  su suite repetida en verde. Nuevos: `ChatGuidedMejorasLogicTests` y `ChatGuidedMejorasCreationTests`.
- XCUITest: `IAGuiadosUITests` (9, con los recorridos nuevos y las capturas en claro y oscuro),
  `YalaAILote14UITests` (saludo) y el paso 3 de Primeros pasos: 11/11, con el centinela en 0.
- Review independiente del diff: 8 hallazgos, los 8 corregidos con su test (ver el PR).
- iPhone 14: los dos guiados escritos con los números en palabras, hasta crear. El dictado físico no se pudo: el
  teléfono no oye el Mac. Guion en `tickets/qa/2026-11-15-ia-guiados.md`.
