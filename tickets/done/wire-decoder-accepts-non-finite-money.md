---
id: wire-decoder-accepts-non-finite-money
status: done
priority: medium
area: "cloud-sync, currency"
created: 2026-09-08
updated: 2026-10-08
source: review adversarial de repair-queue-has-no-exit-for-partial-rate-rows (2026-09-08)
---

# Un importe no finito puede entrar por el canal nube y no sale nunca

## Qué pasa

`WireValueDecoder.double` convierte el valor de wire sin comprobar que el número resultante sea
finito. `Double("nan")` devuelve `NaN`, y ese valor entra por `Apply.moneyReq(\.amount)`
(`EntityApplyMap.swift`) directamente a `TransactionItem.amount`.

La salida está cerrada en el otro sentido —`Canonc1Codec` rechaza los no finitos al EMITIR, con
canario— así que un `NaN` que entre no puede volver a salir: se queda en el dispositivo.

## Por qué importa más de lo que parece

Un `amount` no finito **degenera todo guard de igualdad sobre las columnas derivadas**, porque
`NaN != NaN` es `true`. En concreto, `TransactionItem.recalculatePreferredCurrency` volvería a
escribir esa fila en cada arranque: es justo el bucle que
`repair-queue-has-no-exit-for-partial-rate-rows` cerró para el resto de la población.

Y el número se pinta. Un total que incluya un `NaN` se propaga a cualquier suma que lo toque.

## Qué NO es

**No es una regresión del guard de igualdad.** El decoder es anterior y el agujero existe igual sin
él; lo que cambia es que ahora hay una fila que se comporta distinto al resto.

## Criterio de hecho (AC)

- [x] `WireValueDecoder.double` rechaza (o cuarentena) los valores no finitos, con el mismo criterio
      que `Canonc1Codec` usa al emitir — las dos direcciones deben coincidir.
- [x] Test con `"nan"`, `"inf"` y `"-inf"` en el wire, en las dos direcciones.
- [ ] Comprobar si hay filas así ya en producción antes de decidir si hace falta una cura. **Pedido, sin medir**: ver
      «Producción: sin medir — pedido» abajo. La cura queda propuesta (A/B/C), no aplicada.

## Medido el 2026-10-08 (sesión `wire-decoder-accepts-non-finite-money`)

**Qué llega por el wire.** `Double(String)` acepta `nan`, `NaN`, `NAN`, `inf`, `-inf`, `Infinity`, `infinity`, `snan`
y `nan(0x1)`, y convierte `1e400` en `inf` (sonda con `swiftc` sobre el toolchain de esta Mini). Un número JSON no
finito no llega nunca: `JSONDecoder` rechaza `1e400` («Number 1e400 is not representable in Swift») y `NaN` sin
comillas. ⇒ el agujero era solo la rama `.string` de `WireValueDecoder.double`, que es justo la forma en que PostgREST
sirve un `NUMERIC`.

**Puede existir en el servidor.** Las 14 columnas de dinero y tasa son `NUMERIC(18,4)`/`(18,8)`
(`supabase-staging.ddl`), y `'NaN'` cabe en un `NUMERIC` con precisión (los infinitos no). El gateway valida la forma
de cada delta, no su valor (`validateUpsertShape`), así que un cliente que no pase por `Canonc1Codec` —o una escritura
directa por PostgREST del dueño de la fila— lo guarda. Hallazgo aparte: `gateway-push-accepts-non-finite-numbers`.

**El mismo decoder tenía un crash.** `WireValueDecoder.int` hacía `Int(Double(s))`: con `"nan"`, `"inf"` o `"1e300"` el
proceso abortaba dentro del apply, en cada pull. Entró en el arreglo.

## Qué se hizo

- `WireValueDecoder.double` devuelve `nil` para todo no finito (criterio `isFinite`, el de
  `Canonc1Codec.decimalFixed`), e `isNonFiniteNumber` separa ese caso de un `null` o un tipo equivocado. `int` trunca
  sin abortar.
- **Canal personal: cuarentena.** Un upsert de tabla cableada con dinero o tasa no finitos (las columnas que pasan por
  `Apply.moneyReq/moneyOpt`, marcadas `isMoney`) va ENTERO a `SyncQuarantine`: el cursor avanza, el delta queda
  guardado y el Merkle salta la tabla mientras esté ahí. Una versión posterior de la fila (upsert o tombstone)
  retira los deltas viejos y mueve el testigo `quarantinePendingCount` en el mismo save. `drainQuarantineOnce` no
  los re-aplica. Por qué no aplicar «sin la columna»: el born-remote nacía en 0 USD y una fila existente mezclaba
  dos versiones del grupo `money`. Hoy un dinero obligatorio malformado (`"abc"`) sigue como estaba: se deja sin tocar.
- **Grupos: saltar el delta con rastro** (`groupsApplyNonFiniteMoney`), su patrón para lo que no se puede
  materializar; no tiene cuarentena. Gasto, reparto y liquidación no se aplican; en la meta del grupo solo se deja sin
  tocar `budget_limit_amount` (con `nil` se le quitaría el presupuesto a todos).
- Canario `cloudSyncPullNonFiniteMoney` (`<personal|groups>|<tabla>`, una vez por proceso).
- `confidence_*` (columnas TEXT) usan el mismo `double`: un no finito ahí queda `nil`. El blob `rates` de
  `ExchangeRate` ya descartaba los no finitos en su lector (`decodedRates`, `parsed.isFinite`).

- **Mismo agujero en texto:** `scheduled_payments.split_values_raw` (TEXT, pares `uuid:valor`) se parseaba con
  `Double()` en `SplitConfigCodec.decodeValues`; un `uuid:nan` llegaba a la plantilla del gasto de grupo. Ahora se
  descarta como cualquier par malformado.

## Review adversarial (3 lentes, 2026-10-08): ningún hallazgo alto

Corregido tras la review: una nota que dice `"NaN"` sí se aplica (test que mata el mutante «sin `isMoney`»); con una
fila en cuarentena la cuarentena se lee en cada página y, si no se deja leer, la página para (test con control); un
`NaN` sobre otro `NaN` retira el viejo; un save que falla tras retirar no toca nada (test contra el store); la retirada
indexa por fila en vez de recorrer la cuarentena por cada delta; `budget_limit_amount` no finito deja rastro y canario;
comentarios de `SyncMerkle` y `SyncApplyEngine` y la regla de `swiftdata-cloudkit.md` al día.

Medido para cerrar el hallazgo «una fila en cuarentena apaga el Merkle de toda su tabla, también en la verificación
de la migración»: mientras el `NaN` siga en el servidor, su Merkle responde **502** para esa cuenta o ese grupo
(`gateway/src/sync/routes.ts:398`, `gateway/src/groups/routes.ts:633`: el re-serializador no acepta `"NaN"`), así que
la verificación ya no podía converger con o sin el salto local. Al reescribirse la fila llega otra versión y la
cuarentena se retira.

**Residuales aceptados, sin ticket propio (población ~0 sin filas `NaN` en el servidor):**
- Grupos: un gasto saltado cuyos repartos nuevos sí se aplican deja un saldo FINITO que no cierra. Antes el `NaN`
  rompía todos los saldos del grupo.
- Una fila de la cuenta A en cuarentena sobrevive al cierre de sesión (contrato de `CloudSyncRuntime`, línea ~573) y
  apaga el Merkle de esa tabla para una cuenta B en el mismo teléfono.
- La retirada se decide con el testigo `quarantinePendingCount`; con el testigo desfasado a 0 y filas presentes no se
  retira. No hay camino conocido que llegue ahí.
- Previo a este ticket: un dinero obligatorio malformado que no es número (`"abc"`) se sigue dejando sin tocar, así
  que un born-remote con él nace en 0.

## Producción: sin medir — pedido

No hubo lectura de producción en esta sesión. El PAT de gestión (`~/Secrets/yala-supabase-mgmt/pat`) responde
`Invalid access token` y además estaba autorizado solo para staging; el conector de Supabase pide autenticación.
Para medirlo hace falta una de dos cosas de Jürgen: reautenticar el conector de Supabase en esta Mini, o un token
de lectura de producción. La consulta, solo lectura, contando como `postgres` (con `supabase_read_only_user` RLS
esconde las filas y el conteo sale 0 siempre):

```sql
select 'tx_items' t, count(*) from tx_items
 where 'NaN' in (amount, amount_in_preferred_currency, exchange_rate, split_total_amount, split_my_value, split_divisor)
union all select 'budgets', count(*) from budgets where limit_amount = 'NaN'
union all select 'scheduled_payments', count(*) from scheduled_payments where 'NaN' in (amount, split_total_amount)
union all select 'inbox_drafts', count(*) from inbox_drafts where amount = 'NaN'
union all select 'favorite_payments', count(*) from favorite_payments where amount = 'NaN'
union all select 'cashflow_plans', count(*) from cashflow_plans where starting_balance = 'NaN'
union all select 'cashflow_lines', count(*) from cashflow_lines where manual_amount = 'NaN'
union all select 'cashflow_overrides', count(*) from cashflow_overrides where amount = 'NaN';
```

Grupos guarda los importes cifrados (`bytea`): hace falta descifrar con la llave del entorno
(`pgp_sym_decrypt(amount, <llave>) = 'NaN'`). Desde este build el canario cuenta los teléfonos que lo reciben, sin
consulta. Producción tenía 0 cuentas el 2026-09-24 (`verificar-backend-yala`); lo probable es que no haya ninguna.

## Cura en los teléfonos: propuesta, no aplicada

Un teléfono con un `NaN` ya guardado (de un build anterior) no se cura con este arreglo: el apply solo mira lo que
baja. La fila sigue rompiendo sus totales y no sube.

- **A — No curar (recomendada mientras producción no se mida).** Sin cuentas reales en la nube, la población es cero
  o casi; un barrido de arranque que reescribe importes es más riesgo que daño que cura.
- **B — Barrido de arranque que pone en cuarentena local** las filas con un importe no finito (las oculta de los
  totales y deja un aviso «este movimiento llegó dañado»), sin reescribir el importe. Si la medición sale > 0.
- **C — Reescribir a 0 y avisar.** Arregla los totales, pero escribe un importe que la persona no puso. No.

Decisión de Jürgen, si la medición sale distinta de cero.

## Verificación (2026-10-08)

- Suite unitaria completa: 9211 tests, 0 fallos (`Yala Dev`, iPhone 17 Pro iOS 27.0).
- **Control rojo con el comportamiento viejo** (decoder que acepta no finitos, sin cuarentena, Grupos sin salto,
  `SplitConfigCodec` sin filtro, en un mutante con copia): caen 19 de los 47 casos de las cuatro suites tocadas.
  Mutante aparte que quita el salto de `drainQuarantineOnce`: cae `drainQuarantine_keepsTheNonFiniteDelta`.
- XCUITest de las áreas tocadas (`EdgeCasesUITests`, `WelcomeFreshStartAlertUITests`,
  `GroupsAttestTerminalBannerUITests`): 9/10; el rojo es `test_extremeMinimumAmountSaves`, el de
  `new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max`, ajeno y medido sobre `2.1`.
- Sin device-QA: no hay nada visible que cambie en un iPhone.
