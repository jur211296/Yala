---
id: personal-cloudkit-cashflow-override-line-declared-as-reference
status: qa
priority: high
area: "cloudkit, sync, cashflow"
created: 2026-10-10
updated: 2026-10-16
qa-status: needs-testing
qa-notes: espera el despliegue de CD_cashFlowLine a Production (runbook) y luego dos iPhone
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

- [x] Medido el tipo de `CD_CashFlowOverride.CD_line` en Production de `iCloud.com.jurgenschmidt.yala`: REFERENCE
      (export de Jürgen tras el deploy del 2026-10-12).
- [x] Plan de migración decidido con Jürgen (reglas del encargo del 2026-10-16: aditivo, sin perder datos, el
      campo viejo se queda) e implementado, con test.
- [x] `knownTypeMismatches` con la entrada de `CD_line` justificada en el propio test (la propiedad legado sigue en
      el modelo y la app ya no la escribe; un source-scan lo fija).
- [ ] **Jürgen:** desplegar `CD_cashFlowLine` a Production en los dos contenedores y verificarlo con un export,
      ANTES de subir la build a TestFlight. Runbook: `docs/cloudkit-schema-diff-2.1.md`, sección «El campo nuevo
      de los ajustes del flujo de caja (despliegue pendiente)», pasos A a E.
- [ ] **Jürgen:** device-QA en dos iPhone (guion abajo).

## Lo que se hizo (2026-10-16)

- La relación pasó de `CashFlowOverride.line` a `CashFlowOverride.cashFlowLine` (campo nuevo `CD_cashFlowLine`,
  STRING), con su inversa nueva `CashFlowLine.monthOverrides`. `line` y `overrides` se quedan como legado: nadie
  los escribe salvo la migración, que vacía `line`.
- `CashFlowOverrideLineMigration`, en cada arranque (`AppBootstrapper`, junto al wipe de 1.2.7): pasa cada ajuste con
  `line` a `cashFlowLine` y vacía `line` en el mismo guardado (un registro con `CD_line` puesto lo vuelve a rechazar
  Production). Idempotente, sin flag; si la línea ya tiene ese mes en la relación nueva, el viejo es un duplicado
  superado y se borra (nunca llegó al servidor). No inserta nada.
- El formulario del ajuste, el quitar ajuste y el apply/emisión del Modo Nube (`line_ref`) usan la relación nueva;
  el backend no cambia de columna.
- Los cuatro `Cloudkit Schemas/yala*.ckdb` declaran `CD_cashFlowLine STRING` (sin índices). **Chocan con los cambios
  sin commitear de `yala_dev-*.ckdb` del árbol principal de Jürgen** (una línea en cada uno).
- Tests: `CashFlowOverrideLineMigrationTests` (datos viejos, idempotente, sin duplicados, cascada, que nadie vuelva a
  escribir `line`), `PersonalCloudKitSchemaParityTests.cashFlowOverride_travelsByTheNewStringField` y el apply del
  Modo Nube (`CloudSyncWiredEntitiesTests`, ahora con `line == nil`).

## No medible en el Mac

El simulador no tiene iCloud y la Mini no tiene token de `cktool` (medido: «No management token found»): ni la sync
real entre dos dispositivos ni el esquema vivo se pueden ver desde aquí. Que un registro con `line` vacío no traiga
`CD_line` es inferido; lo comprueba el paso 4 del guion.

## Guion de device-QA (tras el despliegue del esquema, con la build nueva en los dos)

1. iPhone A: **Planificación → Flujo de caja**, toca un mes de una línea y ajusta el importe (p. ej. 1.234). Guarda.
2. iPhone B, mismo Apple ID: abre **Flujo de caja**; en uno o dos minutos (o al cerrar y abrir Yala) ese mes enseña
   1.234 con la marca de ajuste.
3. En B cámbialo a 2.000 → A lo ve.
4. **Obligatorio:** antes de instalar la build nueva en A, apunta en A (versión de la App Store) un ajuste de otro mes; instala la build en los dos, abre A una vez y comprueba que aparece en B. Es lo que prueba la migración.

## Residuales con ticket

- `cashflow-override-synced-to-an-old-version-stays-invisible-after-updating`
- `cashflow-two-devices-with-the-same-month-adjustment-end-up-with-two`

## Barrido de QA · 2026-10-16

Barrido de QA 2026-10-16 · se queda: §4 dos iPhone con el mismo Apple ID y, antes, el despliegue del esquema (tuyo). La migración la fijan `CashFlowOverrideLineMigrationTests` y `PersonalCloudKitSchemaParityTests`, con 6 tests que caen ante sus mutantes (#523). Prueba D · ly22 de `docs/qa/tanda-qa-jurgen-2.1.md`; el despliegue va primero, en «Antes de empezar».
