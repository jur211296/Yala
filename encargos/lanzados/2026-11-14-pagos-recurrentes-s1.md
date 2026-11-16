Yala
# Pagos recurrentes: detectar suscripciones en el historial y proponerlas en Planificación (S1)
---
toca: Yala/App/Logic/PagosRecurrentes/,Yala/App/Views/Planning/PagosRecurrentes/,Yala/App/Views/Planning/PlannedPaymentsView.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/PagosRecurrentes/,tickets/done/2026-11-14-pagos-recurrentes-s1.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Definición: docs/ux/atajo-banco-y-suscripciones/ (PR 940, artifact https://claude.ai/artifact/UVJwj3b1KNzYuF85yGwk34). Decisión de Jürgen del 14-nov: se toman todas las recomendadas (S1 a S5 y P1 «tarjeta en Planificación, arriba de la lista de pagos planificados mientras haya algo por responder»).

Construye S1 según la definición: la regla de detección sobre el historial, la tarjeta en Planificación, convertir en pago planificado o descartar, con las respuestas recomendadas de S2 a S5 (cuántos cobros, dónde se recuerda lo descartado, enlace a cobros pasados, cambios de precio y bajas) tal como las marca la página. Si la vista de pagos planificados tiene otro nombre de archivo que PlannedPaymentsView.swift, usa el real y anótalo; si necesitas tocar otro archivo fuera de toca, déjalo como card nueva.

Sin esquema de datos nuevo (las recomendadas no lo cambian). No toques CloudKit Production. Tests en YalaTests/PagosRecurrentes/. Probar de punta a punta en el iPhone 14 por DeviceMCP con un historial de prueba que tenga suscripciones (Netflix, Spotify) y cobros mensuales. En la Max puedes usar un segundo simulador además del de otra sesión. Commits y PR sin firma de IA.

Lo menor y reversible lo decides con la opción recomendada y lo anotas en «Decidido sin consultar». Cierre: si está completo y CI verde, /cerrar-total según el modo de sesión fijado al arrancar, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué fichero es «PlannedPaymentsView.swift»?** → `Yala/App/Views/Planning/ScheduledPaymentsView.swift` (contenedor de Pagos planificados en Planificación). No existe `PlannedPaymentsView.swift`.
Por qué: es la vista que monta el segmentado y la lista; la tarjeta va arriba de ella. Alternativa descartada: `ScheduledPaymentsListView.swift`, que pinta el hero y la lista del mes y no está en `toca`.

**D2 · Respuestas de S1 a S5** → las recomendadas de la página: S1 = P1 (tarjeta arriba en Planificación); S2 = 3 cobros mensuales o 4 semanales, anuales fuera; S3 = lo descartado se recuerda en cada iPhone (sin esquema); S4 = los cobros pasados no se tocan; S5 = cambios de precio y bajas en el lote S2, fuera de este.
Por qué: decisión de Jürgen del 14-nov («todas las recomendadas»).

**D3 · ¿La hoja de «convertir» es el editor de hoy o una propia?** → hoja de propuesta propia en `PagosRecurrentes/` con las filas de la maqueta (monto, frecuencia, próximo cobro, cuenta, aviso) y los tres botones «Crear pago planificado», «No es fijo», «Ahora no»; guarda con `ScheduledPaymentEditorViewModel.savePayment`, el mismo guardado del editor.
Por qué: el `ScheduledPaymentPrefill` del editor no lleva frecuencia semanal ni marca de suscripción, y el editor está fuera de `toca`; la maqueta tiene botones que el editor no tiene. Alternativa descartada: abrir el editor con prefill (semanales saldrían como mensuales) o tocar el editor (fuera de `toca` → card).

**D4 · ¿Dónde viven el interruptor y lo descartado?** → pantalla «Pagos que se repiten» en `PagosRecurrentes/` (interruptor + lista de descartados con «Volver a proponer»), abierta desde el menú «···» de la tarjeta y desde un enlace al pie de Pagos planificados que solo sale si la función está apagada o hay descartados. La fila en Ajustes queda como card.
Por qué: Ajustes está fuera de `toca`; sin una entrada dentro de Planificación, apagar la función no tendría vuelta.

**D5 · Persistencia de lo descartado y lo pospuesto** → `UserDefaults.standard` del dispositivo, en un almacén propio `@Observable` (sin `AppPreferences`, fuera de `toca`). «No es fijo» descarta para siempre (hasta «Volver a proponer»); «Ahora no» oculta hasta que llegue un cobro nuevo de ese comercio.
Por qué: S3 local; «Ahora no» necesita volver sin molestar cada vez que se abre la pantalla. Que el borrado total de datos no limpie estas claves queda como card (`DataWipeService` fuera de `toca`).

**D6 · Textos con número («Encontramos 3 pagos», «Lo pagaste 5 veces»)** → sin plurales: «Pagos que se repiten» y «Cobros encontrados: 5».
Por qué: los `.stringsdict` no están en `toca`.

**D7 · Aviso por defecto del pago creado** → el día del cobro y 1 día antes (como la maqueta), no los 3 días del editor.

**D8 · Exclusiones del historial** → ingresos (`TransactionClassificationLogic.isIncome`), transferencias y ajustes (`transferPairID`, `balanceAdjustmentType`), gastos y liquidaciones de grupo, importe 0, fechas futuras y los cobros que generó un pago planificado que todavía existe. Ventana de 200 días hacia atrás (basta para tres cobros mensuales y los 45 días; no lee el historial entero).

**D9 · Prueba de punta a punta** → semilla `realista` en el iPhone 14, borrando los pagos planificados de Netflix y Spotify para que sus cobros queden sin plan; iCloud+ sigue planificado y sirve de control (no debe salir).

**D10 · `qa/coverage-index.json`** → se actualiza en el mismo commit aunque no esté en `toca`: lo exige el contrato del `CLAUDE.md` del repo para todo cambio bajo `Yala/`.

Nada de esto pide ADR: son decisiones de este lote.
