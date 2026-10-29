---
id: import-account-column-by-name
status: backlog
priority: medium
area: "import, accounts"
created: 2026-10-29
updated: 2026-10-29
source: "auditoría del import 2.2 (sesión S27j), H7 de docs/import/AUDITORIA-IMPORT-2-2.md"
---

# Importar a la cuenta que dice cada fila, y crearla si no existe

**Versión propuesta: 2.4.** Función nueva del tema «cuentas / empezar con datos»: 2.4 según el roadmap. Si Jürgen quiere el caso real entero en 2.2, éste es el que hay que adelantar. La decide Jürgen. Card: `34qe`.

## Qué ve el usuario

Todo va a una cuenta, o a una por moneda: las 7 cuentas del caso real entrarían fundidas en 3, con los saldos mal. Un archivo de una moneda sin cuenta da error, sin ofrecer crearla.

## Evidencia

Las rutas reciben una cuenta o un mapa moneda → cuenta (`TransactionCSVImportService.swift:154`, `:1089`, `:1447`, `:1608`). Sin cuenta de esa moneda: error (`ImportIntroSheet.swift:538-548`); el selector pide crearla antes (`ImportAccountPickerSheet.swift:24-26`).

Detalle y contexto: `docs/import/AUDITORIA-IMPORT-2-2.md`, H7.

## Propuesta

Columna `account` por nombre (tras `exported-csv-cannot-be-imported-back`). Una cuenta que no existe se propone crear en la vista previa con la moneda de sus filas y saldo inicial cero. Si el nombre es el de una tarjeta con líneas por moneda, va a la línea de la moneda de la fila. Sin columna, el flujo de hoy. Archivadas y la de Grupos, fuera.

## Criterio de hecho

- [ ] Un archivo con 3 cuentas entra en esas 3 cuentas.
- [ ] Una cuenta que no existe se crea al confirmar, y la vista previa la anuncia.
- [ ] Ida y vuelta: exportar con `account` e importar deja cada movimiento en su cuenta.
