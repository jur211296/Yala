---
id: transfer-and-adjustment-subcategories-need-a-stable-role
status: backlog
priority: medium
area: "categories, import, schema"
created: 2026-10-29
updated: 2026-10-29
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

- [ ] Jürgen decide el papel de la subcategoría sembrada.
- [ ] Import, selectores y puente de Grupos reconocen transferencias y ajustes sin mirar el nombre.
