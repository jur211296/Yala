Yala
# Pagos que se repiten: banner en Planificación, hoja grande con todos los casos y formulario completo
---
toca: Yala/App/Views/Planning/PagosRecurrentes/,Yala/App/Views/Planning/ScheduledPaymentsView.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/PagosRecurrentesBanner/,tickets/done/2026-11-17-pagos-que-se-repiten-banner-y-hoja.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Parte de lo construido en «Pagos que se repiten (S1)» (PR #983): `Yala/App/Views/Planning/PagosRecurrentes/` (RecurringProposalsCard, RecurringProposalSheet) y su lógica en `Yala/App/Logic/PagosRecurrentes/` (no se toca la detección).

## Qué pidió Jürgen (17-nov, 15:52 Lima, con captura de TestFlight)
No le gusta la tarjeta «Pagos que se repiten» con la lista entera arriba de Pagos planificados. La quiere así:
1. **Banner** compacto en Planificación, en lugar de la tarjeta-lista: «Hemos identificado X pagos que se repiten y podrías añadirlos como recurrentes» (texto final pulido en es-419 neutro, con plural correcto y en los 16 idiomas). Se oculta cuando no queda nada por responder.
2. Al tocarlo, abre una **sheet con detent large** y un título claro (p. ej. «Pagos que se repiten»), con todos los casos (nombre, frecuencia, día, cuenta, moneda y monto, como hoy).
3. Tocar un caso abre el **formulario completo de nuevo pago planificado** (el mismo que «+ Nuevo pago planificado»), prellenado con los datos detectados, en lugar del formulario distinto actual. Al guardar, el caso sale de la lista; descartar sigue disponible (deslizar o menú) como hoy.
Fuera de este lote: íconos y logos de marcas (va después, en otra sesión).

## Cómo entregar
- Si el formulario completo vive fuera de `toca`, reutilízalo sin cambiarlo; si necesitas tocarlo, hazlo mínimo y anótalo en «Decidido sin consultar».
- Probar en claro, oscuro y con el iPhone girado, en el iPhone 14 por DeviceMCP con un historial que tenga cobros mensuales repetidos. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo.
- Tests nuevos en `YalaTests/PagosRecurrentesBanner/`.
- Entregable visual: artifact de Claude con antes y después (banner, hoja y formulario prellenado). Nunca Markdown ni PDF.

## Reglas
- Sin esquema de datos nuevo. No toques CloudKit Production. Commits y PR sin firma de IA, PR contra 2.3.
- Lo menor y reversible lo decides con la opción recomendada y lo anotas en «Decidido sin consultar». Lo vital se pregunta según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni desplegar lo incompleto).
- Cierre: si está completo, CI verde y el modo lo permite, `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (Frank, 2026-11-17, modo semi)

Decisiones (menores y reversibles, tomadas con la opción recomendada):
- **D1 Formulario:** se reutiliza `ScheduledPaymentEditorView` (el de «+ Nuevo pago planificado»). Su prellenado no llevaba
  frecuencia semanal, día típico, suscripción ni monto variable: se añaden cuatro campos opcionales a
  `ScheduledPaymentPrefill` con valor por defecto (los otros dos llamadores no cambian). Además el editor enseñaba la moneda
  de la cuenta aunque guardara la del prellenado (suscripción en dólares en tarjeta en soles): ahora enseña la que guarda.
  Fuera de `toca`, mínimo, anotado.
- **D2 Presentación:** banner → hoja con detent `.large` y título «Pagos que se repiten» → el editor como hoja encima de
  esa hoja, colgado del contenedor (no de la raíz de la pila). Al guardar, el editor se cierra, el caso sale de la lista
  y sale el aviso de siempre («X ya es un pago planificado…  · Ver»). «Ver» cierra la hoja y lleva al mes.
- **D3 Descartar:** en la lista, deslizar (No es fijo / Ahora no) y menú contextual con lo mismo. «Ajustes de las
  propuestas» pasa al menú «···» de la hoja.
- **D4 Copy:** una frase con plural (`.stringsdict`, 16 idiomas): «Encontramos N pagos que se repiten. Puedes agregarlos
  a tus pagos planificados.» El `.stringsdict` no estaba en `toca`: lo exige el plural.
- **D5 Limpieza:** la hoja propia de la propuesta (`RecurringProposalSheet`) queda sin uso y se retira, con sus textos.
- **D6 Hoja vacía:** si al guardar o descartar no queda nada, la hoja se cierra sola y el banner desaparece.

Ficheros: `PagosRecurrentes/` (banner, hoja, textos; fuera la hoja vieja), `ScheduledPaymentsView.swift`,
`ScheduledPaymentEditorView.swift` (D1), 16 `.strings` + 16 `.stringsdict`, `YalaTests/PagosRecurrentesBanner/`,
`qa/coverage-index.json`, ticket en `tickets/done/`.
