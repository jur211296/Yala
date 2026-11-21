Yala
# Límites de Flujo de caja atados a varios pagos planificados y en otra moneda
---
toca: Yala/Models/CashFlowLine.swift,Yala/App/Logic/FlujoMotorMes/,Yala/App/Logic/FlujoTasaDelMes/,Yala/App/Logic/Helpers/ScheduledPaymentAmountConversion.swift,Yala/App/Logic/CashFlowLineSideLogic.swift,Yala/App/Logic/Calculators/CashFlowProjectionCalculator.swift,Yala/App/Views/Reports/CashFlow/CalculoMonto/,Yala/App/Views/Reports/CashFlow/CambiarLimite/,Yala/App/Views/Reports/CashFlow/DetalleLinea/,Yala/App/Views/Reports/CashFlow/DetalleMes/,Yala/App/Views/Reports/CashFlow/CashFlowDetailLineRow.swift,Yala/App/Views/Reports/CashFlow/CashFlowMonthDetailView.swift,Yala/App/Views/Reports/CashFlow/PagosDeLinea/,Yala/Resources/*.lproj/FlujoDetalleLinea.strings,Yala/Resources/*.lproj/FlujoCambiarLimite.strings,Yala/Services/CloudSync/EntityApplyMap.swift,Yala/Services/CloudSync/EntityEmissionMap.swift,Yala/Services/CloudSync/SyncCapability.swift,capability_manifest.json,Cloudkit Schemas/yala-development.ckdb,Cloudkit Schemas/yala-production.ckdb,Cloudkit Schemas/yala_dev-development.ckdb,Cloudkit Schemas/yala_dev-production.ckdb,YalaTests/FlujoLimitesPagosYMoneda/,YalaTests/CloudSync/CashFlowLimitesPagosYMonedaSyncTests.swift,YalaTests/CloudSync/PersonalCloudKitSchemaParityTests.swift,YalaUITests/FlujoLimitesPagosYMoneda/,tickets/backlog/2026-11-20-flujo-limites-pagos-planificados-y-moneda.md,tickets/done/2026-11-20-flujo-limites-pagos-planificados-y-moneda.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Implementa `tickets/backlog/2026-11-20-flujo-limites-pagos-planificados-y-moneda.md` entero, con las maquetas del artifact «Límites con pagos y monedas» y su copia en `docs/maquetas/flujo-limites-pagos-y-moneda/index.html`. Léelo antes de empezar.

## Decisión de Jürgen (20-nov, 17:06, registrada)

«En la de flujo de caja, límites por pagos planificados y monedas también todas las recomendadas, encola.» Valen las ocho recomendadas del ticket:
1. `metodo` A: «Pagos planificados», con uno o varios pagos.
2. `seleccion` B: hoja con casillas; un pago se mueve de línea y nunca queda en dos.
3. `borrado` A: si la línea se queda sin nada, pasa a monto fijo con su último límite y avisa una vez.
4. `mezcla` A: cada pago se convierte por separado y se suma.
5. `fijo` A: el monto fijo puede ir en otra moneda y vale para todos los meses.
6. `tasa` A: el tipo de cambio es el promedio del mes.
7. `fila` A: la fila muestra el original y la cápsula «Cómo se convierte».
8. `sync` A: cuatro propiedades nuevas, compatibles con versiones viejas.

No hace falta leer la colección `decisiones` del artifact: esta respuesta manda.

## Qué construir

Todo «Diseño recomendado», «Criterios de aceptación» y «Pruebas previstas» del ticket. Las vistas nuevas van en carpetas propias (`PagosDeLinea/`, `FlujoTasaDelMes/`) y los textos en `FlujoDetalleLinea.strings` y `FlujoCambiarLimite.strings` (16 idiomas), en español neutro y tuteo. Revisa claro y oscuro y AX5.

Cambia el modelo y la sincronización, así que pasa por el revisor con la checklist de confiabilidad del paso 4 bis de `/gate` y con la de dinero.

## Límites duros

- **iCloud:** los cuatro campos van en los cuatro `.ckdb` del PR, con la prueba de paridad. Despliega el schema solo a **Development**. Desplegar a **Production es un cambio de producción y necesita el OK de Jürgen**: no lo hagas. Déjalo como pendiente en el cierre, con el paso exacto, y avisa que el build no se puede subir hasta que eso esté.
- **Modo Nube:** las columnas van con `since: 8` en `capability_manifest.json` y con la emisión y aplicación del molde de `amount_changes_raw`. La migración de Supabase se aplica solo en dev o staging, nunca en producción. Si la migración vive fuera de este repo o fuera del `toca`, deja el SQL listo en el cierre y anótalo.
- Si hace falta tocar algún archivo fuera del `toca` (por ejemplo `CashFlowPlanViewModel` o `ExchangeRateService`), primero intenta reutilizarlo como está. Si de verdad no hay otra forma, anótalo en «Saltado o asumido sin preguntar» con el motivo.

Haz el device-QA en el iPhone 14 por DeviceMCP con el caso del ticket. En la Max puedes usar un segundo simulador si otra sesión ocupa el primero.

## Al cerrar

Mueve el ticket a `tickets/done/2026-11-20-flujo-limites-pagos-planificados-y-moneda.md`. Si quedó pendiente el despliegue del schema de iCloud a Production, crea una card «Espera decisión» asignada a Jürgen con ese paso.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Dónde viven los pagos de una línea** → `scheduledPaymentIDsRaw` (ids en orden) manda; sin él, el pago de la relación `scheduledPayment` (líneas de antes y de versiones viejas). La relación guarda siempre el primero.
Por qué: compatibilidad hacia atrás sin migración. Alternativa descartada: relación a-muchos (otro campo de CloudKit y otra tabla en la nube).

**D2 · Pago borrado** → lo resuelve el borrado deliberado (`EntityDeletionService.deleteScheduledPayment`, una llamada a `FlujoPagosDeLineaLogica.alBorrarPago`): saca el id de las líneas; si una queda sin pagos ni extra, pasa a «Monto fijo» con el límite del mes en curso (con el pago aún dentro) y deja un aviso local de una vez. Un id que no se resuelve al LEER (borrado en otro teléfono, o aún sin llegar por iCloud) suma 0 y, sin nada más, el límite cae a `manualAmount`; leer nunca escribe.
Por qué: convertir al leer pierde la línea si el pago solo llegaba tarde por iCloud. Alternativa descartada: mutar en el detalle al abrirlo.

**D3 · `manualAmount` en una línea de pagos o en otra moneda** → se guarda el límite convertido del mes al guardar (lo lee una versión vieja y es el respaldo de D2).

**D4 · Tipo de cambio del mes** → `FlujoTasaDelMes`: cerrado = promedio de los días con tasa exacta; en curso = lo mismo hasta hoy; futuro = última tasa, siempre «≈». Sin días exactos: promedio de las tasas arrastradas (≈); sin ninguna, la última (≈). Tasas pedidas en bloque una vez por cálculo (`rateFactors`), a mediodía local.
Por qué: la regla de `BalanceValuation` y una sola consulta. Alternativa descartada: una consulta por mes y línea.

**D5 · Pago pausado** → no suma (antes sumaba). Terminado: lo ya hace el calendario del pago (`endDate`).

**D6 · Mover un pago de línea** → se quita de la otra; si la otra queda sin nada, misma regla que D2 (monto fijo con su límite del mes).

**D7 · Crear el plan (sugerencias)** → sigue con un pago por línea, como hoy; la tarjeta de varios pagos y el extra solo en una línea creada.
Por qué: el armado del plan no está en el ticket.

**D8 · Original en la fila** → «500 USD» con ⇄ si el monto fijo es en otra moneda o todos los pagos están en la misma moneda extranjera sin extra; en una línea de pagos, además «4 pagos + extra» (maqueta).

**D9 · Moneda en los textos** → el código (USD), no el nombre: el plural del nombre no se puede escribir bien en 16 idiomas.

**D10 · «Lo que llevas en la moneda del límite»** → solo en el detalle: si todo lo registrado del mes en la línea está en la moneda del límite y no pasa del original, no sale «Te pasaste» y se explica la diferencia por tipo de cambio.

**D11 · Sync** → las cuatro columnas `since: 8`, apunte POR COLUMNA (molde de la v5) y reemisión al subir. La migración de Supabase queda escrita en `qa/cloud/g33_01_*` sin aplicar: en la Max no hay PAT de la Management API. El app declara la menor versión con el Worker (v7 hoy), así que no emite nada nuevo hasta que el Worker suba.

**D12 · Schema de iCloud** → en los cuatro `.ckdb`; el despliegue a Development tampoco se puede hacer desde aquí (sin token de `cktool`): queda con su paso exacto para Jürgen, junto con Production.

**D13 · Ficheros fuera del `toca`** → `CashFlowCellDetailSheet.swift` (cápsula y aviso del detalle), `EntityDeletionService.swift` (D2), `CashFlowPlanViewModel.swift` y `CashFlowAddLineSheet.swift` (un pago ya usado por cualquier línea, no solo por la relación), `DeltaEmitter.swift`, `CloudSyncEngine.swift`, `AccountLinkReemit.swift`, `supabase-staging.ddl`, `gateway/test/*` y `qa/cloud/` (sync v8), `docs/despliegue-cloudkit-2-2.md`.
