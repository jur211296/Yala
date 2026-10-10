---
id: multi-currency-accounts
status: backlog
priority: medium
area: "accounts, currency"
created: 2026-09-09
updated: 2026-10-08
source: idea Jürgen 2026-09-09
---

# Una cuenta con más de una divisa: la tarjeta que cobra en soles y en dólares

## La idea

Que una misma cuenta pueda llevar saldos en varias divisas a la vez. El caso de Jürgen es una
tarjeta de crédito peruana: cobra en soles y en dólares **por separado**, cada línea con su propio
saldo, pero es una sola tarjeta y el usuario la piensa como una.

## Por qué importa

Hoy la única salida es partir la tarjeta en dos cuentas: dos filas, dos saldos y ninguna vista de
«cuánto debo en esta tarjeta». En Perú la tarjeta bimoneda es lo normal, no un borde.

## Lo medido (2026-09-09)

El supuesto de una divisa por cuenta está en el modelo, no en la pantalla:

- `Yala/Models/Account.swift:17` — `var currencyCode: String = "USD"`. Una propiedad, un `String`.
  Sin arrays de divisas, sin sub-saldos, sin relación a saldos por divisa.
- El saldo se calcula sobre esa premisa: `AccountBalanceCalculator`
  (`Yala/Utils/AccountBalanceCalculator.swift:13`) y `LiveBalanceCalculator`
  (`Yala/App/Logic/Calculators/LiveBalanceCalculator.swift:18`).
- Falso amigo a no confundir: `currencyToSuggestAsSecondary`
  (`AccountFormViewModel.swift:64,394`) **no** es multi-divisa de la cuenta — es una preferencia
  global de visualización (`"secondaryCurrencies"` en `SessionDefaults`).

## Estado

Medido el impacto el 2026-10-08 (sección siguiente). **Espera la decisión de Jürgen**: qué opción, y
las preguntas cerradas del análisis. Sin spec hasta entonces.

## Análisis de impacto (2026-10-08)

Documento completo, con el inventario por área, los comandos `rg` que reproducen cada conteo y las
tres opciones: [`docs/multi-currency-accounts-impact-2026-10.md`](../../docs/multi-currency-accounts-impact-2026-10.md).

1. **34 ficheros (106 líneas)** leen la divisa de una cuenta y **33 sitios** la copian en lo que
   guardan. No hay validador: la regla se cumple porque las entradas copian la divisa de la cuenta, y
   los borradores de la Bandeja ni tienen campo de divisa.
2. **La app ya está partida en dos.** Tarjeta del Panel, ficha, Ajustes, ajuste de saldo, informes
   por cuenta y contexto de IA suman en crudo. Saldo total, presupuestos y estadísticas agrupan por
   divisa.
3. **A**, una tarjeta que agrupa cuentas de una divisa: conserva el invariante y reusa el patrón de
   las cuentas «Grupos PEN». Unos 25-35 ficheros.
4. **B**, saldos guardados por divisa: **se descarta**. Crea una segunda fuente de verdad que dos
   teléfonos se pisan.
5. **C**, la cuenta acepta varias divisas: unos 50-60 ficheros, deshace la política del 9-sep y del
   7-oct, y un teléfono sin actualizar sumaría mal sin avisar.
6. **Recomendación: A1.** La tarjeta es la cuenta principal y cada divisa extra es una línea enlazada
   con un solo campo nuevo. Un teléfono viejo ve dos cuentas sueltas con los números bien.
7. Quien ya partió su tarjeta en dos cuentas las **vincula sin tocar ningún movimiento**.
8. Pagar la línea en dólares con soles es una transferencia FX normal, que ya funciona hoy.
9. Cuatro entregas propuestas: primero modelo, sync y esquema de iCloud sin UI; después la vista de
   la tarjeta; después selectores y captura; al final, informes.
10. Seis preguntas cerradas para Jürgen, cada una con su recomendada, en la sección 5 del documento.

## Relacionados

- [[changing-an-account-currency-orphans-its-whole-history]] (**high**) — el mismo supuesto visto
  por su lado roto: hoy cambiar la divisa de una cuenta deja su histórico en la divisa vieja.
- [[preferred-currency-has-three-different-defaults]] — la otra pata suelta de divisa por defecto.
- [[account-currency-change-leaves-scheduled-and-favorites-stale]] (PR #400) y
  [[saving-a-mismatched-transaction-relabels-it-without-converting]] /
  [[cloudsync-account-currency-orphans-receiver-history]]: la decisión 2A del 2026-10-07. A la
  conserva; C la rediseña.
- [[account-collections]]: se solapa con A en Ajustes y en el filtro, pero es un conjunto para
  filtrar sin saldo ni divisa. Ninguna sustituye a la otra.
- [[cashflow-scheduled-line-ignores-payment-currency]],
  [[bridge-virtual-only-currency-mismatch-is-silent]] y
  [[converted-amount-sweep-blind-to-input-changes]]: deudas de divisa que C agravaría.
- Abiertos por este análisis: [[personal-cloudkit-schema-snapshot-misses-optional-fields]] (high) y
  [[bulk-move-to-another-currency-account-relabels-the-amount]] (medium).
