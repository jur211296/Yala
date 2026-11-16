---
id: 2026-11-15-ia-guiados
status: qa
priority: high
area: ai
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-ia-guiados-presupuesto-y-recurrentes (Jürgen, 15-nov)
qa-status: needs-testing
qa-date: 2026-11-16
qa-notes: probado por texto en el simulador con XCUITest y capturas; falta la voz en el iPhone (guion abajo)
---
# Yala IA: crear presupuestos y pagos planificados con flujos guiados

Jürgen (15-nov): que Yala IA haga más cosas. Para empezar, crear un presupuesto y un pago que se repite conversando,
con la misma experiencia visual de Primeros pasos (tarjetas, chips, varias a la vez, pasos claros) y no solo texto.

## Paso 0 — decisiones (sesión semi, resueltas sin consultar: ninguna es vital)

- **Detección en el teléfono** (`ChatGuidedIntentDetector`) antes del clasificador: no cambia el servidor ni lo que
  sale del teléfono, vale en iCloud y en la nube, no gasta cuota de `chat`. `gateway/` no se toca.
- **Sin guiado** en la prueba de cortesía de Primeros pasos ni cuando la frase es una pregunta.
- **Lo que trae la frase** (monto, período o frecuencia, moneda, categorías, día, nombre) no se vuelve a preguntar y
  sale marcado en la confirmación.
- **Monto sugerido**: promedio de los tres últimos meses cerrados con la regla de gasto de Planificación y «un 10 %
  menos».
- **Moneda**: la principal; se pregunta solo con cuentas en más de una moneda.
- **Aviso del presupuesto**: 75 % y 100 % si las alertas ya están encendidas; si no, ninguno y sin pedir permisos.
- **Sugerencias del pago**: los cobros que se repiten (`RecurringProposalsSource`).
- **Confirmación obligatoria** con «Cambiar» por respuesta; nada se guarda sin «Crear».
- **Guardado** por los ViewModels de los editores.
- **Motor**: `ChatGuidedFlowSpec` + `ChatGuidedEngine`, estado en `ChatAttachment.guided`.
- **Piezas del onboarding** reusadas; a `TutorialQuestionPieces.swift` salen dos cuentas que el chat necesita.

## Entregable

- Guiados de presupuesto y de pago planificado dentro de Yala IA.
- Recorrido visual y catálogo de próximos guiados como artifact.

## Qué se hizo

- **Motor** (`Yala/Services/Chat/Guiados/`): `ChatGuidedFlow` (estado y respuestas, viaja en `ChatAttachment.guided`),
  `ChatGuidedEngine` (specs de presupuesto y pago; siguiente pendiente, «Atrás», «Cambiar», confirmación obligatoria),
  `ChatGuidedIntentDetector` (intención y relleno, en el teléfono), `ChatGuidedDataSource` (categorías con lo gastado,
  cuentas, cobros que se repiten, monto sugerido) y `ChatGuidedCreator` (guarda por los ViewModels de los editores).
- **Tarjeta** (`Yala/App/Views/Chat/Guiados/ChatGuidedFlowCard.swift`) con las piezas de `TutorialQuestionPieces`,
  `FirstBudgetCardPreview` y `FirstPaymentCardPreview`; va a todo lo ancho del hilo (`ChatMessageBubble`) y el hilo baja
  con cada pregunta (`ChatSheetView`).
- **Primeros pasos** usa ahora `TutorialPlanningMath` para lo gastado con presupuesto de prueba, la fecha del primer
  pago, su resumen y «Hoy / Mañana / En N días». Mismo cálculo, sin cambio visible.
- **Textos**: 44 claves `iaGuided.*` en los 16 idiomas (`L10n+IAGuiados.swift`); lo que Primeros pasos ya decía se reusa.

## Pruebas

- `YalaTests/IAGuiados/ChatGuidedIntentAndEngineTests` y `ChatGuidedCreationTests`: intención (pedidos, preguntas,
  mirar y apuntar), relleno, monto sugerido desde el gasto real, motor, confirmación obligatoria, límite del plan,
  creación del presupuesto y del pago, cancelar.
- `YalaUITests/Flows/IAGuiadosUITests`: los dos recorridos pregunta a pregunta, la frase completa y la frase dicha, con
  capturas en el resultado.

## Guion de QA en el iPhone (por voz)

1. Yala Dev con Pro, en el iPhone de pruebas. Abre Registros y toca «Yala IA».
2. Toca el micrófono y di: «Quiero un presupuesto de trescientos al mes para comida». Toca «Listo» y luego enviar.
   - Debe salir la tarjeta «Nuevo presupuesto» con Alimentación marcada, 300 y «Mensual», y llegar a «Revisa antes de
     crear» con «Lo dijiste tú» en esas tres filas.
3. Toca «Crear presupuesto». Sale «¡Listo! Tu presupuesto está creado.»; toca «Ver presupuesto»: se cierra el chat y se
   abre ese presupuesto en Planificación.
4. Vuelve a Yala IA, toca el micrófono y di: «Recuérdame pagar el alquiler el cinco de cada mes, son mil doscientos».
   - La tarjeta «Nuevo pago planificado» empieza por la cuenta (o la categoría si tienes una sola cuenta), sin volver a
     preguntar nombre, monto ni día.
5. Elige cuenta y categoría, revisa y toca «Crear pago». Toca «Ver pago»: se abre en Pagos planificados.
6. Repite el paso 2 con la app en inglés («I want a budget of 300 a month for food»): mismo resultado.
