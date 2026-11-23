---
id: import-transfer-pairing-ignores-accounts-and-currency-changes
status: done
priority: medium
area: "import, transfers"
created: 2026-10-29
updated: 2026-11-22
source: "auditoría del import 2.2 (sesión S27j), H9 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# La heurística de transferencias no mira la cuenta ni el cambio de moneda

**Versión propuesta: 2.4.** Media, mejora del import: 2.4. Necesita `import-account-column-by-name`. La decide Jürgen. Card: `cbjx`.

## Qué ve el usuario

De las 50 patas de transferencia del caso real se emparejarían 17 pares; las otras 16 patas quedan sueltas, todas con cambio de moneda. Sueltas siguen fuera de gastos e ingresos, pero borrar una no borra la otra y el detalle no dice a qué cuenta fue.

## Evidencia

`TransferPairReconcileService.computePairingPlan` (`:95-128`) agrupa por día, importe absoluto y moneda y solo empareja grupos de 1 negativo + 1 positivo. No mira la cuenta. El import la llama en `TransactionCSVImportService.swift:1760-1785`. Medido con el caso real (cifras agregadas).

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H9.

## Propuesta

Para archivos de fuera (los de Yala usan `transfer_id`): exigir cuentas distintas cuando haya columna de cuenta; emparejar con cambio de moneda cuando en el día haya exactamente una salida y una entrada sueltas en cuentas distintas; con más candidatos, desempatar por cuenta y nota. La vista previa dice cuántas quedan sueltas.

## Criterio de hecho

- [ ] Tests: PEN → USD el mismo día se empareja; dos de 100 el mismo día entre cuentas distintas se emparejan por cuenta; dos patas de la misma cuenta no.
- [ ] La vista previa cuenta las sueltas.

## Hecho (2026-11-22, lote 1 de Importar registros)

- `ImportTransferPairingLogic`, propia del import (el reconciliador de arranque no cambia): mismo día, importe y moneda
  con cuentas distintas; con varios candidatos desempata la cuenta y luego la nota, y si sigue habiendo dudas no
  empareja. Cambio de moneda: en un día con exactamente una salida y una entrada sueltas, en cuentas y monedas
  distintas. Dos patas de la misma cuenta no se emparejan nunca (antes sí).
- La vista previa dice cuántas transferencias quedan sin su otra parte.
- No dependía de `import-account-column-by-name`: las cuentas ya salen de la cuenta elegida, de la moneda o de la columna
  `account`.
- Pruebas: `ImportarLote1LogicaTests` (PEN → USD, A → B y B → A, misma cuenta, A → B y C → D sin nota y con nota, dos
  iguales, una entrada con dos orígenes) e `ImportarLote1ImportTests` (PEN → USD por moneda queda con el mismo
  `transferPairID`; la vista previa cuenta las sueltas).

- [x] Tests: PEN → USD el mismo día se empareja; dos de 100 el mismo día entre cuentas distintas se emparejan por cuenta; dos patas de la misma cuenta no.
- [x] La vista previa cuenta las sueltas.
