---
esfuerzo: high
---
# Import: reconocer las transferencias en los 16 idiomas (incluido el ajuste de saldo) y deshacer lo insertado si el import falla a medias

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `import-transferencias-rollback` · Sesión cola **S27l** · al cerrar → **S27m** (import por nombre de columna, cuenta, Excel, montos y puente de Grupos).
Cards: `tablero ver tablero-la-subcategoria-de-transferencias-no-se-ynsq` (H2) · `tablero ver tablero-si-el-import-falla-al-final-lo-insertado-a27x` (H6).

## Contexto
Decisión de Jürgen (2026-10-29 13:05 Lima): siete hallazgos de la auditoría del import van a 2.2. Se reparten en dos sesiones seguidas. Esta es la primera y la más acotada: no toca la lectura del archivo ni la cabecera. La siguiente (S27m) unifica las cuatro rutas de validación en un `RawImportRow` común; por eso esta sesión debe dejar sus cambios fáciles de mover: una sola función o un solo punto de decisión de «es transferencia / es ajuste», que las cuatro rutas llamen igual.

La auditoría está en `docs/import/AUDITORIA-IMPORT-2-2.md` y los tickets en `tickets/backlog/`, del PR #689 (rama `encargo/2026-10-29-import-auditoria-mejoras`). Si al arrancar #689 aún no entró en `origin/2.2`, léelos con `git show origin/encargo/2026-10-29-import-auditoria-mejoras:<ruta>`, sin traer esa rama a la tuya. Lee H2 y H6 y sus tickets (`transfer-subcategory-unrecognized-in-five-languages`, `import-failure-leaves-unsaved-inserts-in-the-main-context`).

- **H2**: `Subcategory.transferNames` (`Subcategory.swift:115-123`) no tiene los nombres de ja, nl, pl, zh-Hans ni pt («Transferência entre contas»), ni los de la subcategoría sembrada `subcategory.accountTransfer` («Account transfer», «Kontoüberweisung»…). Con Yala en esos idiomas, una transferencia importada cuenta como gasto e ingreso. Además el ajuste se distingue con el texto del idioma **actual** (`TransactionCSVImportService.swift:222`), así que «Ajustes de saldo» sembrado en español con el teléfono en inglés se marca como transferencia. La decisión se repite en `:220-228`, `:1153-1161`, `:1540-1547` y `:1709-1716`.
- **H6**: los dos `catch` de `ImportIntroSheet.swift` (`:760-777`, `:870-887`) cierran la hoja sin `modelContext.rollback()`: lo insertado lo guarda el siguiente `save` de cualquier pantalla.

## Qué se pide
1. Las dos cards a in progress con `--agente frank` al empezar.
2. H2: completar las listas con todos los nombres de `transfer.categoryName` y `subcategory.accountTransfer` de los 16 idiomas, y decidir el ajuste con `balanceAdjustmentNames` (todos los idiomas), no con el texto actual. Un solo punto de decisión para las cuatro rutas. Test de paridad que recorra los `.lproj` y falle si un idioma trae un nombre que la lista no tiene. El arreglo de fondo (papel estable / `isSystem` en el esquema) NO va aquí.
3. H6: `rollback()` en los dos `catch`, con un test que fuerce el fallo después de insertar y compruebe que el contexto queda limpio.
4. Tests con casos reales: archivos sintéticos con transferencias nombradas en cada idioma y un ajuste en español con locale en inglés. Abre también `/Users/jur/Downloads/Yala_Registros_27-oct-2026_con-transferencias.xlsx` (está en la Mini) para comprobar qué nombres de transferencia trae y que se reconocen; ese archivo **nunca** se sube al repo ni se copian sus datos a tests o docs.
5. Review adversarial antes del PR: busca otro sitio que decida transferencia por texto (selectores, «Top categorías» en `Subcategory.swift:128-136`) y dilo en el cierre si existe; no lo amplíes.
6. Un PR a 2.2. Cards a done (o a in qa si queda algo que solo Jürgen puede ver).

## Qué NO tocar
- La cabecera, el lector de Excel, el parser de montos, la columna de cuenta y el puente de Grupos: son de S27m.
- Esquema SwiftData. marketing/ y Web/. No lanzar otras sesiones.

## Reglas de Mini
Pipeline serial Yala: limpiar → build `xcodebuild -jobs 2` sin sim booteado → boot 1 sim → tests → apagar y borrar ese sim. Nada de solapar build y tests. Borra al lanzar y al cerrar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- Un archivo con transferencias en ja, nl, pl, zh-Hans y pt importa sin sumar a gastos ni ingresos; el ajuste en español con el teléfono en inglés sigue siendo ajuste.
- Un import que falla tras insertar no deja nada en el contexto.
- Test de paridad de idiomas en verde; PR a 2.2 abierto.

/cerrar-total

## Paso 0 (Frank, 2026-10-29, auto-contestado)

1. **Un solo punto de decisión**: `TransactionCSVImportService.systemAdjustmentType(for:)` devuelve el tipo (`adjustment` / `transfer` / `nil`) y las cuatro rutas lo llaman igual. Mantiene la regla de hoy: toda subcategoría de sistema que no sea ajuste es transferencia (incluidas las `isSystem` del puente, que son de S27m).
2. **Ajuste por lista, no por idioma actual**: `balanceAdjustmentNames.contains(name)`.
3. **Listas — decidido por Jürgen (2026-10-29, AskUserQuestion, opción «Fuera»)**: `transferNames` gana los 16 `.lproj` de `transfer.categoryName` (ja, nl, pl, zh-Hans y pt con tilde eran los que faltaban). Las subcategorías SEMBRADAS (`subcategory.accountTransfer` / `…Other`) no entran con su propio nombre: la review vio que la lista también decide `isAnySystem` en toda la app (en en/de/nl/ja/zh desaparecerían de los selectores y Grupos perdería la clasificación del usuario en el re-bridge), que «口座振替» es una domiciliación en japonés y que una exportación propia cambiaría de cifras al reimportarla. Donde su texto coincide con el de las transferencias (es, fr, it, pl, pt) ya eran o pasan a ser de sistema por esa coincidencia. Se conservan los nombres viejos (incl. «Transferencia entre contas» sin tilde).
4. **Paridad**: test que recorre `Yala/Resources/*.lproj`: exige `transfer.categoryName` en `transferNames`, que una sembrada esté en la lista solo si su texto coincide con el de las transferencias, y que ninguna lista pise a la otra. El de `balanceAdjustment` ya lo fijaba `UXAudit22ReviewFixesTests`.
5. **H6**: el «importar y guardar» pasa a `TransactionCSVImportService.importAndSave(in:save:_:)`, que hace `rollback()` si falla la importación o el guardado; los dos `catch` de la hoja quedan cubiertos. Para que el rollback solo se lleve lo del import (la review recordó que `CurrencyChangeService` rechaza un rollback amplio), lo pendiente de otras pantallas se guarda ANTES de empezar —es lo que el `save()` del import ya hacía al acabar bien— y el cuerpo del import no suspende.
6. Excel real de Jürgen: 50 transferencias «Otros › Transferencia entre cuentas», en español. No se copia nada al repo.
7. **Alcance del import — decidido por Jürgen a mitad de sesión (opción «Fuera solo Grupos»)**: nada de Grupos entra por el import (subcategorías del puente y categoría «Grupos»; tendrá su importación propia); transferencias y ajustes de saldo sí, marcados. Lo de Grupos es de S27m: anotado en la nota de la card `l2g9`. Aquí `systemAdjustmentType` mantiene «`isSystem` ⇒ transferencia» hasta que S27m salte esas filas.
