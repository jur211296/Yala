---
id: group-presence-predicates-disagree-on-archived-and-hidden
status: backlog
priority: medium
area: "groups, welcome, icloud"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `restore-treats-budgets-and-groups-as-no-data` (2026-09-21): las dos lentes lo cazaron por separado"
---

# Tres sitios preguntan «¿tiene grupos?» y cada uno cuenta unos distintos

## Medido (2026-09-21)

| Dónde | Predicado | Archivados | Ocultos (`isHiddenForAll`) |
|---|---|---|---|
| `ICloudAccountSummary.groupsCount` (`iCloudSyncService.swift`) | `!$0.isArchived` | **no** cuenta | **sí** cuenta |
| `ContentView.checkHasExistingData()` (`:1350`) | sin predicado | sí cuenta | sí cuenta |
| El resto del repo | `!isHiddenForAll` | sí cuenta | **no** cuenta |

El tercero es el mayoritario y está en cinco sitios: `BridgeResolverLogic.swift:35`,
`AccountDeletionDebtLogic.swift:29`, `GroupExpenseEligibilityLogic.swift:36`,
`AppBootstrapper.swift:430`, `ScheduledPaymentEditorView.swift:1219`.

Dos hechos que cierran el cuadro:

- **Un grupo archivado se ENSEÑA.** `GroupsViewModel.archivedGroups` es
  `isArchived && !isHiddenForAll` (`GroupsViewModel.swift:96`) y `GroupsContainerView.swift:627-649`
  le pinta su sección. Es dato vivo y recuperable.
- **`isHiddenForAll` es el soft-delete FU-02, «irreversible in-app»** (`SplitGroup.swift:29`).

## Dónde muerde hoy

`groupsCount` **ya no decide** desde que `restore-treats-budgets-and-groups-as-no-data` dejó los
grupos fuera de `hasAnyData`, pero **sí decide qué card se pinta**: quien tenga dos grupos borrados
con el soft-delete y ninguno vivo puede ver «2 grupos compartidos» en la pantalla del hallazgo, y
quien solo tenga archivados no ve ninguna card aunque la app se los siga enseñando en Grupos.

`checkHasExistingData()` sí decide —es el `deviceHasData` de la puerta del paso 4, o sea quién
recibe el aviso con doble confirmación antes del borrado `.handover`— y es el más ancho de los
tres. Ahí ancho es el lado seguro, así que no urge, pero conviene que sea ancho **a propósito** y
no por omisión.

## Qué habría que decidir

- ¿Cuál es el predicado canónico de «este teléfono tiene grupos»? El mayoritario
  (`!isHiddenForAll`) parece el candidato: cuenta lo archivado, que se enseña, y descuenta lo
  borrado, que no.
- ¿Se unifica en un helper, como se hizo con la identidad del member? Tres criterios sobre el mismo
  hecho es como divergen.

## Relación con otros tickets

- `restore-treats-budgets-and-groups-as-no-data` — de donde sale.
