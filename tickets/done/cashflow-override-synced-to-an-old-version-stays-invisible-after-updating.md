---
id: cashflow-override-synced-to-an-old-version-stays-invisible-after-updating
status: done
priority: low
area: "cloudkit, sync, cashflow"
created: 2026-10-16
updated: 2026-10-17
qa-status: needs-testing
qa-notes: dos iPhone, paso 5 del guion de la card ly22
source: residual de personal-cloudkit-cashflow-override-line-declared-as-reference (2026-10-16)
---

# Un ajuste de un mes que llega a un teléfono con versión vieja no se ve al actualizarlo

## Qué le puede pasar al usuario

Tiene dos iPhone. Actualiza Yala en el A antes que en el B. Los ajustes de un mes del flujo de caja del A
viajan ahora por el campo nuevo de iCloud (`CD_cashFlowLine`). El B, con la versión vieja, recibe el ajuste pero
no conoce ese campo: lo guarda sin línea y no lo enseña. Al actualizar el B, el ajuste **sigue sin verse** ahí
hasta que alguien lo edite en el A.

## Lo que se sabe y lo que no

- Medido: la versión vieja no borra un ajuste sin línea (2.0.4 no tiene ningún borrado de huérfanos salvo el
  wipe de 1.2.7, ya consumido), así que no se pierde nada: el ajuste sigue en el A y en iCloud.
- **Inferido, sin medir:** que el espejo de SwiftData no vuelve a bajar un registro que ya bajó cuando el modelo
  gana un campo. Si lo re-bajara, este ticket no existe.
- Solo afecta a ajustes que viajaron mientras el otro teléfono seguía en la versión vieja. Antes del cambio no
  viajaba ninguno en Production (el campo viejo los rechazaba).

## Cómo medirlo

Dos iPhone con el mismo Apple ID, el esquema ya desplegado (`docs/cloudkit-schema-diff-2.1.md`, «El campo nuevo de
los ajustes del flujo de caja»): A con la build nueva, B con la de la App Store. Ajusta un mes en A, espera, actualiza
B y abre Flujo de caja. Si el ajuste aparece, cerrar como no reproducible.

## Si se confirma

El ajuste huérfano del B tiene registro en iCloud con `CD_cashFlowLine` puesto. Opciones: forzar en el A una
reescritura de sus ajustes en el primer arranque tras una fecha (barato, idempotente) o leer el registro de iCloud
del huérfano en el B. Decide Jürgen.

## Cerrado (2026-10-17)

**Medido en el binario de Core Data de la Mac (no en un aparato).** El espejo de CloudKit guarda los hashes del
modelo del cliente (`PFCloudKitMetadataClientVersionHashesKey`) y tiene un «zone fetch after client migration»
(`PFCloudKitMetadataNeedsZoneFetchAfterClientMigrationKey`, `_needsImportAfterClientMigration`,
`cleanUpAfterClientMigrationWithStore:`). Apunta a que, al actualizar a una versión con otro modelo, vuelve a bajar
la zona entera, y con ella el `CD_cashFlowLine` del ajuste huérfano. Eso es lo contrario de lo que este ticket
infería. Sin dos aparatos no se puede afirmar más.

**Qué hace el código, se confirme o no.**
- El ajuste sin ninguna línea **no se borra nunca**: la pasada de arranque lo deja fuera porque no tiene clave
  natural. Borrarlo viajaría a iCloud y se llevaría el ajuste del otro teléfono.
- Cuando el espejo le pone la línea, se ve sin hacer nada más (la inversa `monthOverrides` lo recoge).
- Si choca con un ajuste del mismo mes que ese teléfono apuntó con la versión vieja, lo resuelve la regla del
  ticket `cashflow-two-devices-with-the-same-month-adjustment-end-up-with-two`: los dos teléfonos se quedan con el
  mismo.

Tests: `CashFlowOverrideLineMigrationTests`, sección «Un ajuste que llegó a una versión vieja».

**Si el device-QA lo desmiente** (el ajuste sigue sin verse en B tras actualizar), queda la opción del ticket que no
toca el esquema: que A reescriba sus ajustes una vez. Un campo nuevo de iCloud no hace falta para ninguna de las dos.
