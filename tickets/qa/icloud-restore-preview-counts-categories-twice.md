---
id: icloud-restore-preview-counts-categories-twice
status: qa
priority: low
area: "welcome, icloud"
created: 2026-11-05
updated: 2026-11-06
source: "QA en el iPhone de pruebas del 2026-11-05 · relacionado: card tablero-al-activar-la-nube-algunas-categorias-y-70nl"
---

# «Ya tienes datos en tu iCloud» cuenta 124 categorías y la pantalla siguiente 62

Al reinstalar Yala Dev y elegir iCloud privado, «Ya tienes datos en tu iCloud» dijo «1 registro, 2 cuentas, **124
categorías**»; tras «Traer mis datos», la confirmación «¡Hola Jur!» dijo **62**. 124 = 2 × 62: la primera cuenta
duplicados que la restauración funde. Una segunda vez, con los datos ya subidos, las dos dijeron 62. La persona ve dos
cifras distintas para lo mismo. Captura: `~/Claude/entregas/2026-11-05-qa-dispositivo-fisico-device-mcp/evidencia/hallazgo-restaurar-62-categorias.jpg`. iPhone 14, iOS 27.2, Yala Dev
sobre `origin/2.2` (#809).

## Resolución (2026-11-06, lote de cuenta e iCloud)

- **Causa (inferida, no medida en el teléfono):** la sonda de «Ya tienes datos en tu iCloud»
  (`ICloudPersonalCorpusProbe`) contaba los registros `CD_Subcategory` de la zona tal cual, y la zona traía cada
  subcategoría de fábrica dos veces (124 = 2 × 62) — dos siembras subidas antes de que el deduplicador las fundiera —.
  Al restaurar, `SubcategoryDedupLogic` las funde y la pantalla siguiente cuenta el almacén: 62. La segunda vez la zona
  ya estaba fundida y las dos decían 62.
- **Qué cambia para el usuario:** las dos pantallas dicen la misma cifra de categorías.
- **Cómo:** la sonda cuenta las subcategorías de fábrica una vez por la MISMA clave del deduplicador
  (`ICloudCorpusCategoryTally`, que llama a `SubcategoryDedupLogic.identityKey(categoryKey:…)`). Las del usuario, las de
  sistema y las que no traen categoría legible se cuentan una a una, como hace el deduplicador: la cifra puede salir de
  más, nunca de menos. `desiredKeys` baja ocho campos más (`CD_isDefaultSeed`, `CD_isSystemSubcategory`,
  `CD_sortOrder`, `CD_iconName`, `CD_name`, `CD_category`, `CD_colorHex`, `CD_isIncome`).
- **Tests:** `ICloudCorpusCategoryTallyTests` (dos siembras cuentan una, categoría que llega después, las del usuario,
  sin categoría, mismo nombre en dos categorías y paridad de la clave con el deduplicador).

## Guion de device-QA (iPhone de pruebas, Yala Dev)

Reproducir el 124 exige una zona con la siembra duplicada, que ya no existe en la cuenta de pruebas (la segunda vuelta
del 5-nov la fundió). El guion comprueba que las dos cifras coinciden y que la sonda sigue leyendo la zona.

1. En el iPhone 14, borra Yala Dev e instálala desde Xcode.
2. En la bienvenida, «Es mi primera vez» → privacidad total (iCloud privado).
3. En «Ya tienes datos en tu iCloud», anota las cifras (registros, cuentas, categorías).
4. Toca «Traer mis datos» y, en «¡Hola …!», compara: las categorías deben coincidir con el paso 3.
5. Si la pantalla del paso 3 dijera «reintentar» en vez de las cifras, apúntalo: es la lista de campos ampliada.
