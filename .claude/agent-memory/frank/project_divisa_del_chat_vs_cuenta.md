---
name: divisa-del-chat-vs-cuenta
description: PR #107 — el borrador del chat ya se guarda en la divisa de su cuenta; el hueco grande que queda es editar la divisa de una cuenta, y falta device-QA (sí simulable).
metadata:
  type: project
---

**El chat ya no puede dejar una transacción en una divisa distinta a la de su cuenta** (PR #107,
mergeado el 2026-09-08). Manda la cuenta, y la divisa **vive en el borrador**: se sincroniza al
elegir cuenta y se congela al guardar.

**Why:** el saldo agrupa por `tx.currencyCode` y convierte con la tasa de HOY, así que una fila USD
en una cuenta PEN daba un saldo que no cuadraba **y se movía solo**. Medido en el barrido: el chat
era el **único** hueco de creación de los nueve ficheros que construyen `TransactionItem(` — las
otras ocho rutas estampan `account.currencyCode`, `InboxDraft` ni siquiera tiene campo de divisa, y
el import CSV, el bridge de Grupos y los formularios de grupo ya tenían guarda explícita.

**How to apply:**

- **Lo que queda abierto y es mayor que esto:** `changing-an-account-currency-orphans-its-whole-history`
  (**high**) — `AccountFormViewModel:374` cambia `account.currencyCode` también en la ruta de update,
  sin gate por `isEditing` y sin reestampar nada, así que desempareja el histórico **entero** de una
  cuenta de una vez. De paso rompe el round-trip: la exportación escribe `transaction.currencyCode` y
  la importación rechaza toda fila cuya divisa no sea la de la cuenta destino. Espera decisión de
  Jürgen.
- **Device-QA pendiente y SÍ simulable**: dictar en una divisa sin cuenta, elegir una local, ver que
  la etiqueta del monto cambia antes de guardar, y que el saldo cuadra después.
- **Al tocar esta zona, dos hechos que la doc no dice y cuestan un grep:** `findAccount(byCurrency:)`
  es exacto **y ÚNICO** (`0 ó 2+ → nil`), no «exacto o nil» — con dos cuentas en la divisa dictada
  también falla, y ahí las divisas ni difieren. Y la tarjeta del chat **no tiene ni un
  `accessibilityIdentifier`**, así que ningún XCUITest puede afirmar sobre ella: la red es unit.
- Se descartó a propósito **convertir** el importe (cambiaría el número que el usuario confirma) y
  **añadir `currencyCode` a `updateDraft`** (sería un segundo mando para lo mismo).

Relacionado: [[mi-fix-hereda-la-forma-del-bug]] — el primer intento derivaba la divisa en la tarjeta
y reabrió el bug en el borde de la cuenta archivada; es el quinto mecanismo de esa memoria.
