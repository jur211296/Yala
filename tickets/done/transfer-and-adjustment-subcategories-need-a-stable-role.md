---
id: transfer-and-adjustment-subcategories-need-a-stable-role
status: done
priority: medium
area: "categories, import, schema"
created: 2026-10-29
updated: 2026-11-13
source: "auditoría del import 2.2 (H2, «arreglo de fondo… va aparte») y review de S27l"
---

# Las subcategorías de transferencia y de ajuste se reconocen por su nombre, no por su papel

**Deuda con decisión pendiente de Jürgen** (toca esquema SwiftData y CloudKit). La auditoría del import lo dejó «aparte» y no tenía ticket.

## Qué pasa hoy

`Subcategory.isAnySystem` decide por nombre (`transferNames` y `balanceAdjustmentNames`) o por `isSystem`. Eso tiene tres efectos:
- La subcategoría sembrada de transferencia (`subcategory.accountTransfer` / `…Other`) es de sistema en es, fr, it, pl y pt, porque su texto coincide con el de las transferencias. En en, de, nl, ja y zh es normal: se elige a mano y se puede borrar. El 2026-10-29 Jürgen decidió dejarla así en S27l. Meterla en la lista la sacaba de los selectores y hacía perder la clasificación del usuario en el puente de Grupos.
- Una subcategoría que el usuario cree con uno de esos nombres pasa a ser de sistema sin quererlo. En japonés «口座振替» es una domiciliación.
- Cada idioma nuevo obliga a ampliar las listas (lo fija `TransferNamesParityTests`).

## Propuesta

Un papel estable en el modelo (p. ej. `systemRole`), con despliegue del campo a CloudKit Production, migración que lo rellene en las existentes y lectores que lo usen en vez del nombre. Antes hay que decidir qué es la subcategoría sembrada de transferencia en cada idioma.

## Criterio de hecho

- [x] Jürgen decide el papel de la subcategoría sembrada (2026-11-13: de sistema en todos los idiomas; reemplaza la del 29-oct).
- [x] Import, selectores y puente de Grupos reconocen transferencias y ajustes sin mirar el nombre.

## Resolución (2026-11-13)

- **Modelo:** `Subcategory.systemRoleRaw: String?` y `systemRole` (`SubcategorySystemRole.transfer` / `.balanceAdjustment`).
  `isSystemSubcategory` e `isAnySystem` leen el papel, así que los ~30 lectores (selectores, borrado, estadísticas, puente)
  cambian sin tocarse. Con el campo vacío, el papel se deduce solo en las que creó Yala (`isDefaultSeed`): una creada a
  mano con el mismo nombre queda normal.
- **Migración:** `SubcategorySystemRoleBackfill`, en cada arranque tras la quiescencia. Escribe el papel; una del usuario
  con nombre de sistema solo lo toma si ya guarda movimientos de ese papel (el importador las creaba con
  `isDefaultSeed: false`). La sembrada de transferencia de en/de/nl/ja/zh, que era normal, se separa: lo que el usuario
  apuntó en ella pasa a una copia suya con el mismo nombre (movimientos que no son transferencias —incluidas las patas
  del puente de Grupos—, favoritos sin destino, programados, borradores, presupuestos con su espejo CSV, comercios y
  líneas del flujo).
- **Medida de la migración** (store sembrado en es y en, `SubcategoryStableRoleTests`): 7 subcategorías con papel y 0
  copias si nadie usó la sembrada a mano; con uso a mano, 1 copia y lo apuntado movido (2 movimientos + 2 registros en el
  caso del test). En un teléfono real son, como mucho, 2 subcategorías de transferencia sembradas + 1 de ajuste + las que
  creó el formulario: del orden de 3-6 filas de `Subcategory`. No se midió un store de producción.
- **Resolver, saldo inicial, migración vieja, fusionador de ajustes de la nube:** por papel. Los que crean, crean con papel.
- **Importador:** el archivo solo trae texto, así que el texto de la fila da el papel (transferencia y ajuste en los 16
  idiomas, más los nombres sembrados de transferencia) y la fila va a la subcategoría con ese papel, no a una con ese
  nombre.
- **Nube:** campo nuevo en los cuatro `Cloudkit Schemas/yala*.ckdb`. El canal personal del Modo Nube no lleva columna
  nueva: cada teléfono deriva el papel con la misma regla sobre campos que ya viajan.
- **Residuales:** dos teléfonos que separan la misma sembrada antes de verse crean dos copias (sin pérdida; se funden con
  «Mover registros»). Una fila exportada de esa copia («Account transfer») se reimporta como transferencia: el archivo
  no distingue; lo cerraría `export-import-carry-record-kind-and-transfer-pair`. Una sembrada que el usuario renombró
  queda normal (se trata como suya).
- **Paso del release:** desplegar `CD_systemRoleRaw` a Production en los dos contenedores ANTES de subir el build.
