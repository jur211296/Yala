---
id: personal-cloudkit-cashflow-override-line-declared-as-reference
status: backlog
priority: high
area: "cloudkit, sync, cashflow"
created: 2026-10-10
updated: 2026-10-10
source: diff del esquema personal (personal-cloudkit-schema-snapshot-misses-optional-fields, 2026-10-10)
---

# Los ajustes de un mes del flujo de caja pueden no sincronizar: el esquema dice REFERENCE y la app escribe STRING

## Qué le puede pasar al usuario

Ajusta el importe de un mes en una línea del flujo de caja. En su otro dispositivo el ajuste no aparece
nunca, y la app no avisa de nada.

## Lo medido (2026-10-10, árbol `cd1138023`)

- `Cloudkit Schemas/yala-production.ckdb` y `yala-development.ckdb` declaran
  `CD_CashFlowOverride.CD_line REFERENCE`. Los `yala_dev-*` lo declaran `STRING`.
- El espejo de CloudKit de SwiftData guarda toda relación a-uno como `STRING` (el recordName del destino):
  las otras 15 relaciones a-uno de esos mismos snapshots son `STRING`. `CashFlowOverride.line` es una
  relación a-uno (`Yala/Models/CashFlowOverride.swift`).
- `CD_CashFlowOverride` es el único record type del snapshot sin ningún índice, lo que sugiere que se creó a
  mano (import de un fichero) y no desde un build. [inferido]
- La relación existe desde `ce20edafe` (2026-03-17, versión 1.1.1).
- `PersonalCloudKitSchemaParityTests` lo tolera solo con ese tipo exacto (`knownTypeMismatches`).

**No medido:** el tipo vivo en Production. Se mira en el paso 1 de `docs/cloudkit-schema-diff-2.1.md`.

## Si Production dice REFERENCE

Un tipo no se puede cambiar en Production. El arreglo es de código: la relación pasa a otra propiedad, con
otro nombre, y por tanto a un campo nuevo de CloudKit (el nombre del campo sale del de la propiedad). Hay
que decidir con Jürgen cómo se migran los ajustes que ya existen.

## Si Production dice STRING

El snapshot estaba mal. Se re-exporta y se quita la entrada de `knownTypeMismatches`.

## Criterio de hecho (AC)

- [ ] Medido el tipo de `CD_CashFlowOverride.CD_line` en Production de `iCloud.com.jurgenschmidt.yala`.
- [ ] Si es REFERENCE: plan de migración decidido con Jürgen e implementado, con test.
- [ ] `knownTypeMismatches` vacío y el test en verde contra el export real.
