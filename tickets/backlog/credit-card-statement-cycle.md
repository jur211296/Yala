---
id: credit-card-statement-cycle
status: backlog
priority: high
area: accounts-crud
created: 2026-10-26
updated: 2026-10-26
source: tablero-tarjeta-de-credito-fecha-de-corte-fecha-nmtk
---
# Tarjeta de crédito: fecha de corte, facturado / por facturar y aviso antes de pagar

Card `nmtk`. Jürgen, 19-oct: **no es una función nueva**, son ajustes sobre la tarjeta de crédito que Yala ya tiene.
Paridad primero (corte + pago + facturado / por facturar + aviso N días antes), mejor UI después. Referencia de
competencia: Pablo (usapablo.com). Estado: **spec + propuesta visual, esperando que Jürgen elija variantes** (decisión
del 26-oct: no se implementa a ciegas).

## Medido hoy (árbol `origin/2.2` @ 393459ddb)

- **Modelo.** `Account` guarda solo `creditCardPaymentReminder: Bool` y `creditCardPaymentDay: Int` (1…28)
  (`Yala/Models/Account.swift:40-41`). No hay día de corte ni límite.
- **Formulario.** `AccountFormView.creditCardSection` (`:1164`): un toggle «Avisar en fecha de pago» y, **solo si está
  encendido**, el selector «Día de pago» 1…28. Quien no quiere aviso no puede guardar su día de pago.
- **Aviso.** `ScheduledPaymentNotificationService.checkAndNotifyCreditCardPayments` (`:508`) **no está programado**:
  corre al arrancar o volver a la app (`AppBootstrapper:3389`) y dispara una notificación inmediata
  (`UNTimeIntervalNotificationTrigger(1)`, `NotificationService`) **solo si ese día es el día de pago**. Si la persona
  no abre Yala ese día, no hay aviso. Texto: «Hoy toca pagar tu tarjeta %@ 💳», sin importe. Al tocarlo abre la ficha
  (L10-14, `AlertDeepLink.account`). Dedup por tarjeta y día (`creditCardNotif_<id>_<fecha>`).
- **Ficha.** `AccountDetailSheet`: hero con «Por pagar» (la deuda total, `PanelAccountCardLogic` `.toPay`), selector de
  línea, «Así se forma tu saldo en este período», gráfica y movimientos. No distingue ciclo.
- **Calculadora** (`BalanceCalculatorSheet`): el modo tarjeta pide el gasto de la tarjeta; no sabe de cortes.
- **Flujo de caja** («Entradas y salidas»): plan mensual por **categorías** (`CashFlowPlanViewModel.generateSuggestions`).
  Los gastos con tarjeta ya cuentan el mes en que se hacen, y el saldo inicial (`CashFlowSetupLogic.todayBalance`) ya
  resta la deuda de la tarjeta si está en el total. Pagar la tarjeta es una transferencia entre cuentas propias:
  **sumarla como salida contaría dos veces.**
- **Tarjeta con varias divisas.** Los ajustes de tarjeta son de la principal (`AccountCardLogic.ownsCardSettings`); las
  líneas los heredan. Un banco peruano factura cada divisa por separado: facturado y por facturar van **por línea**.
- **Sync.** Los dos campos viajan por CloudKit y por el Modo Nube (`EntityEmissionMap:563`, `EntityApplyMap:546`,
  columnas `credit_card_payment_*` en `supabase-staging.ddl` y `capability_manifest.json`).

## Qué se propone (paridad)

1. **Formulario:** «Día de corte» y «Día de pago» siempre visibles en la sección Tarjeta de crédito, separados del
   aviso. Debajo, el aviso con cuántos días antes.
2. **Ficha:** bajo el hero, el estado de cuenta del ciclo:
   - **Facturado** — lo que debías al último corte, menos lo que pagaste después. «Paga antes del 5 nov».
   - **Por facturar** — lo gastado desde el último corte. «Entra en el corte del 15 nov».
   - La suma de los dos es el «Por pagar» de hoy (el número del hero no cambia).
3. **Aviso** N días antes del pago, **programado** (llega aunque no se abra la app), con el importe facturado:
   «Visa: paga S/ 1.240 antes del jueves 5». Si ya está pagado, no se manda. Sigue abriendo la ficha.
4. **Flujo de caja:** en el mes del pago, una fila informativa «Pago de Visa · 5 nov · S/ 1.240 — ya cuenta en tus
   gastos», que **no suma** al total.

Definiciones (fijadas aquí para que la implementación no las reinvente):

- Ciclo: corte el día `C`. El último corte es el día `C` más reciente ≤ hoy; el pago que le toca es el primer día `P`
  posterior a ese corte (si `P ≤ C`, cae en el mes siguiente). Días 1…28, como hoy: todos los meses los tienen.
- `deudaAlCorte` = saldo de la línea al final del día de corte (23:59:59; regla de `DateInterval` del `CLAUDE.md`).
- **Facturado pendiente** = `max(0, deudaAlCorte − pagosDesdeElCorte)`; pagos = entradas a la tarjeta después del
  corte (transferencias e ingresos).
- **Por facturar** = `max(0, deudaHoy − facturadoPendiente)`.
- Sin día de corte configurado: la ficha se queda como hoy y el aviso solo puede ser «el mismo día», sin importe.

## Decisiones que toma Jürgen

Propuesta visual (maquetas + capturas de hoy): https://claude.ai/artifact/79WtHXffxzPfs3YtZFSiET

| # | Pregunta | A (recomendada) | B |
|---|---|---|---|
| D1 | Formulario | Corte y pago siempre visibles; aviso aparte | Todo dentro del toggle del aviso, como hoy |
| D2 | Ficha | Bloque «Estado de cuenta» bajo el hero; el hero sigue en «Por pagar» | El hero se parte en Facturado + Por facturar |
| D3 | Aviso | Elegible: el mismo día · 1 · 3 · 5 días antes | Fijo: 3 días antes y el mismo día, sin ajuste |
| D4 | Flujo de caja | Fila informativa en el mes del pago, sin sumar | Nada en 2.2: solo ficha y aviso |

Por qué A en D3: el día de corte ya obliga a un campo nuevo con su despliegue de esquema; un segundo campo en el mismo
despliegue cuesta casi lo mismo.

## Coste que va con cualquier variante

- **Campos nuevos en `Account`** (`creditCardStatementDay: Int?` y, con D3-A, `creditCardReminderDaysBefore: Int`):
  esquema de CloudKit personal en los cuatro `Cloudkit Schemas/yala*.ckdb`, desplegado a Production **antes** del build
  que los escribe (`.claude/rules/swiftdata-cloudkit.md` L173). Ese despliegue lo hace Jürgen en la consola.
- **Modo Nube:** columnas con `since` y subida de `manifest_version`; orden DDL → Worker → app (L175).
- El aviso pasa del canal «al abrir» al **programado**, con re-plan en cada arranque y tras editar la tarjeta o
  registrarle un pago (patrón `replanSummaries`, single-flight).

## Plan de implementación (tras el OK)

1. Modelo + sync (dos canales) + `.ckdb` + DDL/manifest, con sus tests de paridad.
2. `CreditCardStatementLogic` puro: ciclo, facturado y por facturar por línea. Tests con corte a medianoche, `P ≤ C`,
   pago parcial, sobrepago y cambio de hora.
3. Formulario (D1) + ViewModel + tests de `AccountFormViewModel`.
4. Ficha (D2).
5. Aviso programado (D3) + dedup + re-plan; tests en `ScheduledPaymentNotificationServiceTests`.
6. Flujo de caja (D4).
7. l10n en todos los idiomas; XCUITest del formulario y la ficha (seed `tarjeta-dos-lineas` con corte);
   `qa/coverage-index.json` (`accounts-crud`, `scheduled-payment-notifications-robustness`).
8. Review adversarial (cálculo financiero + notificaciones).

## Fuera de alcance

- **Pago mínimo** e **intereses** (Pablo los calcula): dependen de la tasa y la fórmula de cada banco, que Yala no
  tiene. Candidatos para «mejor UI» tras la paridad.
- Límite de crédito / disponible.
- Días de corte 29-31 («último día del mes»).
