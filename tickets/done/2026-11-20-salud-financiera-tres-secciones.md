---
id: 2026-11-20-salud-financiera-tres-secciones
status: done
priority: medium
area: "panel, salud-financiera"
created: 2026-11-20
updated: 2026-11-20
source: "Jürgen, 20-nov-2026, con capturas de su iPhone; maquetas en el artifact «Salud financiera en tres secciones»"
---

# La hoja de Salud financiera, en tres secciones y en tono de consejero

Jürgen, 20-nov, sobre la hoja que abre la nota del Panel: no sigue el diseño del resto de la app y es alarmista. «No
alcanza para tus pagos del mes» con un −33.974 en rosa gigante, dos veces. Pide tres secciones claras, una por parte de la
nota (Presupuestos, Compromisos, Ritmo), y un tono que explique y proponga qué hacer.

Maquetas (seis estados, claro y oscuro, opciones A, B y C, textos y preguntas): artifact «Salud financiera en tres
secciones», https://claude.ai/artifact/3DGVHSBZxo1BFp9nf7xybw. Sus respuestas se guardan en la colección `decisiones` de
ese artifact (`ArtifactData list`). **Antes de empezar, léelas**: lo que no esté contestado se construye con lo recomendado.

## Diseño recomendado (opción A)

Una sola hoja, de arriba abajo:

1. **Nota.** El aro con la nota total, un titular y una frase de consejero que dice qué mueve más la nota este mes.
   Debajo, las tres cápsulas en el orden de las secciones (Presupuestos, Compromisos, Ritmo) con su número; **tocar una
   baja a su sección**. Una parte que no cuenta no enseña «—»: dice por qué («Crea uno», «Agrega pagos», «Desde el 1
   dic» para un presupuesto creado a mitad de mes, que `FinancialScoreCalculator.bucketIsValid` deja fuera hasta el mes
   siguiente).
2. **Presupuestos** (rótulo «Pesa 40 % de tu nota» y una cápsula de estado: Bien, Para revisar, Sin datos). Tarjeta con
   una frase de estado y los presupuestos con su barra (los de hoy, mismo orden: `SaludFinancieraDetalleLogica.ordenar`).
   Pasado: barra y «Te pasaste por» en ámbar, sin rojo ni cifra grande. Debajo, «Para mejorar esta parte», filas con
   chevron (nunca un botón debajo de otro):
   - **Ajusta el límite a lo real** si el presupuesto se pasó en 3 de los últimos 4 períodos: promedio de esos períodos
     (`BudgetsViewModel.calculateSpending` por período) y un límite propuesto redondeado. Abre el editor del presupuesto
     con el monto escrito; la persona confirma.
   - **O recorta donde más pesa**: las 3 subcategorías o categorías con más gasto dentro del presupuesto en el período.
     Abre Registros filtrado.
   - **Pro:** la primera fila es una tarjeta del resumen con IA de Estadísticas del mes en curso si ya existe
     (`StatsAIAutoRefreshStore`, página `.summary`, el slot del mes; `LLMInsightCard` con `sentiment == "attention"` y su
     `tip`). **Sin llamada nueva a IA.** Si no hay resumen guardado, solo las filas calculadas y «Ver tu resumen».
   - **Sin Pro:** las filas calculadas y una línea discreta «Con Yala Pro, tu resumen con IA te dice en qué se fue el
     gasto» (según la pregunta 6).
   - Sin presupuestos: frase, la categoría con más gasto medio de los últimos 3 meses como sugerencia y «Crear un
     presupuesto».
3. **Compromisos** («Pesa 35 % de tu nota»). Compara **Tu dinero hoy** (la cifra chica del hero del Panel,
   `PanelMoneyScopeLogic`: sin tarjetas de crédito) con **Te falta pagar este mes** (pagos planificados de gasto de hoy
   al fin de mes, sin pagados ni saltados, convertidos a la moneda de la app; la suma de «Lo que te falta pagar» de
   Estadísticas › Resumen, `InsightsCalculator.pendingPaymentsAmount`). **Nunca** «Al 30 tendrías»
   (`MonthEndBalanceLogic`): parte del saldo con tarjetas y suma gasto estimado; de ahí sale el −33.974 de la captura.
   - Frase: «Te faltan pagar S/ X este mes y hoy tienes S/ Y.» + «Te alcanza, y te quedarían S/ Z.» o «Podrías mover
     algún pago a diciembre o revisar si alguno ya no corresponde.»
   - Dos barras a la misma escala; si no alcanza, «Te faltarían S/ Z para cubrirlo todo» en ámbar.
   - Ingresos planificados que llegan antes de fin de mes: se nombran, no se suman («Además esperas S/ X de tu sueldo el
     28 de noviembre…»), según la pregunta 7.
   - La lista de los pagos pendientes de este mes (no 14 días: lo de diciembre no entra) y una fila «Revisar o mover
     pagos» / «Ver tus pagos planificados» que abre Pagos planificados.
   - Pago vencido: primera fila, sin rojo («Luz del Sur venció ayer. Si ya lo pagaste, márcalo como pagado.»). Cuenta en
     negativo: línea bajo la comparación.
   - Sin pagos planificados: frase, «Encontré cobros que se repiten» con lo que propone `RecurringPaymentDetector` (si
     hay) y «Agregar un pago». Sin nada pendiente: «Ya pagaste todo lo planificado de noviembre» y el próximo pago.
4. **Ritmo** («Pesa 25 % de tu nota»). La racha de hoy, simple: días seguidos, la tira de 14 días y una frase. La
   evolución de la racha (¿semanal?) va en su propia sesión; idea en el artifact.
5. **¿Cómo se calcula?**, plegado, como hoy.

Se van «Para revisar» y «Para subir tu nota» como secciones sueltas: sus avisos y pasos pasan a la sección de la parte que
mueven. Textos nuevos en `SaludFinancieraDetalle.strings` (16 idiomas), nunca en `Localizable.strings`. Los textos de
cada estado, en el artifact (español neutro, tuteo).

## Preguntas abiertas (con recomendación; ninguna bloquea)

1. Opción: **A** (B: una sección a la vez con chips; C: consejos primero).
2. Cápsulas como índice que baja a su sección: **sí**.
3. ¿La nota de Compromisos usa también «Tu dinero hoy»? **Sí, en este trabajo**: hoy su cobertura usa el saldo de las
   cuentas elegibles del Panel, tarjetas incluidas (`calculateCommitments`, `LiveBalanceCalculator.liveBalance` sobre
   `context.eligibleAccounts` en `PanelViewModel`), y la hoja y
   la nota se contradirían. Cambia la nota: pasa por el revisor con checklist (dinero).
4. Pagos que cuentan: **hasta fin de mes**.
5. Límite propuesto con monto escrito en el editor: **sí**.
6. Línea discreta hacia Pro sin Pro: **sí**.
7. Ingresos que llegan este mes: **nombrarlos sin sumarlos**.

## Hecho cuando

- La hoja abre con la nota y tres secciones en el orden de las cápsulas; tocar una cápsula baja a su sección.
- Ningún monto negativo grande ni «No alcanza» en la hoja: el caso de la captura (tarjeta con deuda alta) enseña la
  comparación «Te falta pagar / Tu dinero hoy» y un consejo.
- «Tu dinero hoy» de la hoja es el mismo número que el del Panel con los mismos datos; «Te falta pagar este mes», el
  mismo que «Lo que te falta pagar» de Estadísticas › Resumen en «Este mes».
- Los seis estados del artifact se ven como en las maquetas en claro y oscuro: todo bien, presupuesto excedido, no
  alcanza, sin presupuestos, sin pagos planificados, sin Pro.
- En Pro con resumen guardado, la tarjeta de IA sale sin ninguna llamada de red nueva; sin resumen, la hoja no la pide.
- Presupuesto creado a mitad de mes: la cápsula y la sección dicen desde cuándo cuenta.
- A AX5 y en el iPhone SE nada se corta; las filas concepto-importe bajan el importe con `AdaptiveRowStack`.

## Pruebas previstas

- Unit (`YalaTests/SaludFinancieraDetalle/`): comparación dinero/pagos (alcanza, no alcanza, sin pagos, sin pendientes,
  pago en otra moneda con «≈», pago vencido, pago saltado, pago de diciembre fuera); paridad de «Tu dinero hoy» con el
  hero del Panel y de lo pendiente con `InsightsCalculator`; propuesta de límite (3 de 4 períodos pasados → promedio
  redondeado; 2 de 4 → no propone); recorte (top 3 dentro del presupuesto); estado de cada sección y texto de cada
  cápsula (incluido «Desde el 1 dic»); selección de la tarjeta de IA guardada (solo `attention`, solo del slot del mes,
  ninguna sin resumen) y que no hay llamada a `InsightsLLMService`.
- Si se toca la nota (pregunta 3): `FinancialScoreCalculatorTests` con tarjeta de crédito endeudada, y la paridad de la
  cobertura con la hoja.
- XCUITest (`YalaUITests/SaludFinancieraDetalle/`): abrir la hoja, tocar cada cápsula y ver su sección; caso «no
  alcanza» sin cifra negativa; acción «Revisar o mover pagos» abre Pagos planificados. Capturas de los seis estados con
  el seam de capturas que ya existe (`SaludFinancieraDetalleCapturasUITests`).
- Device-QA en el iPhone 14: el caso de la captura de Jürgen con sus datos dev.

## Resultado (20-nov-2026, sesión nocturna)

Construida la opción A con las siete respuestas recomendadas (decisión de Jürgen del 20-nov, 17:02).

- **Hoja**: la nota con su titular, una frase de consejero (`SaludFinancieraDetalleLogica.consejo`) y las tres cápsulas
  como índice (tocar una baja a su sección; sin nota dicen por qué: «Crea uno», «Desde el 1 dic», «Agrega pagos»).
  Secciones Presupuestos, Compromisos y Ritmo con «Pesa N % de tu nota» y su estado (Bien, Para revisar, Sin datos);
  «¿Cómo se calcula?» plegado al final. Se fueron «Para revisar» y «Para subir tu nota».
- **Presupuestos**: barras con «Te pasaste por» en ámbar; «Para mejorar esta parte» con la tarjeta de IA guardada (solo
  Pro, sin llamada de red: `StatsAIAutoRefreshStore`, `.summary`, guardado este mes, solo `attention` con consejo),
  «Ajusta el límite a lo real» (3 de 4 períodos pasados → promedio redondeado hacia arriba), «Recorta donde más pesa»
  (top 3 dentro del presupuesto → Registros filtrado) y, sin Pro, la línea discreta hacia Pro.
- **Compromisos**: «Tu dinero hoy» (`PanelMoneyScopeLogic`, sin tarjetas) frente a «Te falta pagar este mes»
  (`FinancialScoreCalculator.pendingOccurrences`, la misma cuenta que la nota), dos barras a la misma escala, «Te
  faltarían S/ X» en ámbar, pagos vencidos primero y sin rojo, ingresos del mes nombrados sin sumarlos, la lista del mes
  y «Revisar o mover pagos». Sin pagos: «Encontré cobros que se repiten» (`RecurringProposalsSource`) y «Agregar un pago».
- **La nota** (pregunta 3): la cobertura de Compromisos usa las cuentas de «Tu dinero hoy» (`coverageAccounts`), así que
  una tarjeta con deuda alta ya no la hunde.

Fuera, con ticket: el límite propuesto no queda escrito en el editor
(`2026-11-20-editor-presupuesto-limite-propuesto`), «Lo que te falta pagar» de Estadísticas cuenta ingresos y saltados
(`2026-11-20-lo-que-te-falta-pagar-cuenta-ingresos-y-saltados`) y la nota no se recalcula al cambiar qué cuentas son
«Tu dinero hoy» (`2026-11-20-nota-no-recalcula-al-cambiar-tu-dinero-hoy`).
