Yala
# Crear un recurrente a partir de un registro: menú, detalle, bandeja y Recurrentes
---
toca: Yala/App/Views/Records/Components/RecordRowContextMenu.swift, Yala/App/Views/Records/TransactionDetailSheet.swift, Yala/App/ViewModels/RecordsViewModel.swift, Yala/App/Views/Inbox/InboxView.swift, Yala/App/Views/Inbox/InboxDraftRowView.swift, Yala/App/Views/Inbox/InboxDraftEditSheet.swift, Yala/App/Views/Inbox/InboxApproveSuccessView.swift, Yala/App/Views/Planning/ScheduledPaymentEditorView.swift, Yala/App/ViewModels/ScheduledPaymentEditorViewModel.swift, Yala/App/Views/Planning/ScheduledPaymentsListView.swift, Yala/App/Views/Planning/ScheduledPaymentsView.swift, Yala/App/Views/Planning/PagosRecurrentes/, Yala/App/Logic/RecurringFromRecord/, Yala/Utils/L10n.swift, YalaTests/RecurrenteDesdeRegistro/, tickets/backlog/recurrente-desde-registro.md, tickets/done/recurrente-desde-registro.md
esfuerzo: high
cierre: cierra-sola
---

## Qué pidió Jürgen (15-nov, 08:39 Lima; GO 08:40)
Ejemplo real: le llega el correo de Cloudflare, manda captura a Yala, aparece en la bandeja y lo aprueba. Pero Cloudflare ya es un gasto recurrente y hoy:
- desde la bandeja no se puede crear un recurrente;
- en el registro, el menú (mantener presionado) y el detalle traen Duplicar / Editar / Eliminar, pero no hay acción rápida de recurrente; la única vía es entrar a Editar y convertirlo, poco intuitivo;
- crear el recurrente de cero es trabajoso cuando ya hay un registro que sirve de plantilla.

## Qué construir (las tres entradas llegan al mismo editor)
1. **«Hacer recurrente»** en `RecordRowContextMenu` y en `TransactionDetailSheet`. Abre `ScheduledPaymentEditorView` prellenado desde el registro: monto, moneda, categoría/subcategoría, cuenta, nota/comercio; día de cobro = día de la fecha del registro; frecuencia por defecto mensual. El usuario solo confirma. El registro de origen queda vinculado como primer pago (pagado) del recurrente, sin duplicar el gasto.
2. **Bandeja**: junto a Aprobar, «Aprobar y hacer recurrente» (en la fila o la hoja de edición del borrador, según el patrón actual). Un solo flujo: aprueba el borrador como registro y abre el editor de recurrente prellenado; ese registro queda como primer pago. Si el borrador ya viene de un recurrente, no se ofrece.
3. **Recurrentes**: el botón de nuevo ofrece «A partir de un registro», con un selector de registros recientes (buscable) que prellena el editor igual.
4. **Sin duplicados**: si ya existe un recurrente parecido (mismo comercio/categoría y monto cercano, misma moneda), ofrecer «Vincular a <recurrente>» en vez de crear otro. Reutiliza la lógica de propuestas de recurrentes existente (`PagosRecurrentes/`) si sirve.
5. Registros de grupo: decide lo razonable (ocultar la acción o mantener el comportamiento de recurrente de grupo existente) y anótalo.

Fuera de alcance: favoritos (Jürgen lo dejó para otra vez).

## Reglas
- Base `2.3`, PR a `2.3`. Commits y PR sin firma de IA.
- Textos en español neutro latinoamericano, en L10n; VoiceOver con nombre en la acción nueva; iPad (menú contextual y teclado) coherente con Duplicar.
- Tests nuevos en `YalaTests/RecurrenteDesdeRegistro/` (prellenado, vínculo del primer pago, no duplicar gasto, detección de parecido, bandeja).
- Prueba de punta a punta en el iPhone 14 por DeviceMCP o simulador; en la Max puedes usar un segundo simulador si otro proyecto ocupa uno.
- Sin cambios de esquema en CloudKit Production ni Supabase Production; si hace falta un campo nuevo, para y pregunta.
- Lo menor decídelo tú y anótalo en «Decidido sin consultar». Entrega con artifact visual de Claude (antes/después de las tres entradas) y `/cerrar-total` si queda completo.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi; ninguna es vital ni irreversible): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Cómo queda el registro como primer pago sin duplicar el gasto?** → Se reusa el molde del botón «Recurrente» del editor de registros: el registro recibe `scheduledPaymentID`, el recurrente `lastPaidDate` y la próxima fecha avanza más allá del registro. No se crea ninguna transacción.
Por qué: es el mismo vínculo que ya usa la app y el que `processDuePayments` reconoce (`hasLinkedTransaction`). Alternativa descartada: un campo nuevo (cambio de esquema, prohibido).

**D2 · Registro de hace meses (selector de Recurrentes): ¿qué pasa con los vencimientos entre el registro y hoy?** → Se saltan sin borrador; el primer vencimiento pendiente es el de hoy o el siguiente.
Por qué: la persona ya tendrá esos pagos apuntados; pedirlos en la Bandeja los duplicaría. Alternativa descartada: un borrador por mes pasado.

**D3 · «Sin duplicados»: ¿cuándo un recurrente es «parecido»?** → Misma moneda, mismo tipo, monto ±15 % (el margen de «Pagos que se repiten»; los de monto variable no comparan monto) y mismo comercio (marca o nombre, con `RecurringPaymentDetector`). Sin nombre en uno de los dos, misma subcategoría. Nombres distintos nunca casan por subcategoría. Activos y personales solamente.
Por qué: reusa la lógica de propuestas existente; «Netflix» y «Disney+» comparten categoría y no son el mismo pago.

**D4 · ¿Cómo se ofrece «Vincular»?** → Una hoja con fases (elegir → editor), no una alerta: «Vincular a «Cloudflare»» y «Crear otro recurrente».
Por qué: una alerta no admite el nombre en el botón (regla de `swiftui-ds.md`) y encadenar alerta → hoja es el molde que brickea; una sola presentación con fases es el patrón seguro.

**D5 · Vincular a un recurrente existente: ¿avanza la próxima fecha?** → Solo si el registro es del día del vencimiento o posterior, o se adelantó pocos días (4 al mes, 1 a la semana, 7 al año). Un borrador pendiente de esa misma ocurrencia se archiva (pasa a descartados, no se borra).
Por qué: sin eso, el borrador del recurrente y el registro vinculado serían el mismo gasto dos veces.

**D6 · Registros de grupo** → La acción no se ofrece en lo que viene de un grupo, ni en transferencias, ajustes de saldo o registros ya vinculados a un recurrente.
Por qué: el editor de registros ya oculta «Recurrente» en lo de grupo (L8-6); el recurrente de grupo se crea desde el grupo.

**D7 · Bandeja: ¿en la fila o en la hoja del borrador?** → En la hoja de edición, bajo «Aprobar», como botón secundario. La fila (deslizar) se queda igual.
Por qué: la hoja es donde se aprueba con todos los campos completos; el deslizar no tiene sitio para una tercera acción.

**D8 · Recurrentes: ¿cómo ofrece el botón de nuevo «A partir de un registro»?** → Una segunda cápsula «Desde un registro» junto a «Nuevo pago planificado» (la secundaria de `TopPrimaryActionPill`). El toque principal sigue creando de cero en un toque.
Por qué: convertir el botón en menú añadiría un toque al camino de siempre.

**D9 · Detalle del registro: ¿dónde va el botón?** → En el pie, junto a Duplicar y Eliminar («Recurrente»), y el detalle presenta su propia hoja.
Por qué: así funciona igual en hoja, columna del iPad y panel de Estadísticas sin tocar cada host.
