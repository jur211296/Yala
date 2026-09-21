---
id: restore-treats-budgets-and-groups-as-no-data
status: backlog
priority: medium
area: "welcome, icloud, restore"
created: 2026-09-20
updated: 2026-09-20
source: "medición durante `restore-says-no-data-when-the-icloud-import-never-settled` (2026-09-20): al buscar la población de `.notFound` concluyente apareció que es EXACTAMENTE ésta"
---

# «No encontramos tus datos» a quien solo tiene presupuestos o grupos en iCloud

## El problema, en lenguaje de usuario

Tengo presupuestos —o grupos compartidos— guardados en iCloud, pero ninguna cuenta, ningún
movimiento y ninguna categoría propia. Reinstalo Yala, toco «Restaurar desde iCloud», y la app me
dice **«No encontramos tus datos. No hay datos asociados a tu cuenta de iCloud»** con mis
presupuestos ahí.

## Medido (2026-09-20)

- `ICloudAccountSummary.hasAnyData` cuenta **tres** cifras y deja fuera las otras dos que él mismo
  transporta: `accountsCount > 0 || transactionsCount > 0 || categoriesCount > 0`
  (`Yala/Services/iCloudSyncService.swift:773-775`). El struct trae además `budgetsCount` y
  `groupsCount`, y `RestoreProgressView` los pinta en vivo mientras bajan
  (`RestoreProgressView.swift`, `liveCounts`) — o sea que la pantalla los enseña subir y luego
  niega que existan.
- `WelcomeRestoreView` decide con ese predicado: `if summary.hasAnyData { state = .found(summary) }`
  y si no, sigue al camino de búsqueda vacía.
- La segunda copia del criterio, `ICloudPersonalCorpusProbe.hasAnyData`
  (`Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift:75-77`), tiene el mismo hueco —
  `truncated || transactions > 0 || accounts > 0 || categories > 0` — y solo lo tapa **por
  accidente**, vía `truncated`, cuando el corpus es tan grande que agota el tope de la sonda. Un
  corpus pequeño de solo presupuestos no lo agota y cae por el mismo sitio. Su propio docblock
  declara que sigue «el mismo criterio» que el otro, así que las dos se mueven juntas.

## Por qué aparece ahora

Al cerrar `restore-says-no-data-when-the-icloud-import-never-settled` había que decidir en qué
casos «Empezar desde cero» pregunta antes, y el término era si la búsqueda había concluido
(`settled`). Buscando quién alcanza `.notFound` **con** la búsqueda concluida salió que
`settled == true` exige un `.importEvent` exitoso —o sea, que CloudKit trajera algo—, y que si
trajo algo y aun así `hasAnyData` es `false`, lo que trajo son presupuestos o grupos. **Ésa es la
única población de ese camino**, y es esta.

Por eso aquel ticket dejó `.notFound` confirmando SIEMPRE: mientras este hueco siga abierto, la
rama que llamaba directo le hacía daño justo a la gente que sí tiene datos.

## Criterios de aceptación

- [ ] Un corpus de iCloud que solo tenga presupuestos (o solo grupos) NO produce el mensaje que
      niega los datos.
- [ ] Las dos copias del criterio quedan alineadas, o se reduce a una sola.
- [ ] Al ampliar el predicado, revisar los OTROS consumidores: `.found` enseña las cifras con
      `visibleCountItems`, y `WelcomePrivateICloudGateLogic` decide `.foundData` / `.ask` /
      `.standDown` con el mismo criterio — ampliarlo cambia también a quién se le pregunta antes
      de borrar, que es el lado bueno, pero hay que medirlo antes de darlo por gratis.

## Relación con otros tickets

- `restore-says-no-data-when-the-icloud-import-never-settled` — de donde sale.
- `restore-beacon-outlives-account-deletion` — también razona sobre qué cuenta `hasAnyData`.
