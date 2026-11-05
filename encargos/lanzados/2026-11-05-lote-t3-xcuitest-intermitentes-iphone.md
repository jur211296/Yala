# Lote T3 · XCUITest intermitentes en iPhone (SE, iOS 27 y en lote)
toca: `YalaUITests/Flows/`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial, sim-lock).
Lote tests (cola-2-3-propuesta.md §3 T3). Va después de T2, que toca la misma carpeta.

Cards:
1. El test del aviso de divisa secundaria sale rojo en el iPhone SE porque vuelve atrás con el primer botón de la barra.
2. El test del paywall retenido tras el aviso de la Bandeja falla solo cuando corre en lote con otras cinco clases.
3. El XCUITest del aviso de pérdida al cambiar de Apple ID falla en iOS 27.
4. Los dos tests de edición masiva (`BulkEditUITests`) fallan en el iPhone SE.
5. Tests · tres XCUITest intermitentes (importe mínimo en iOS 27, enlace que pierde el importe, Registros en horizontal).

Hecha cuando: los cinco en verde tres corridas seguidas en iPhone SE e iOS 27, y en lote.

PREGUNTAR, NO SALTAR. `tablero` + cierre con la sección «Saltado o asumido sin preguntar». Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-05 11:40)

- **Base:** el worktree nació de `2.2`; el encargo dice `2.3` ⇒ rama recreada sobre `origin/2.3` (sin commits propios aún).
- **T2 sigue abierto** (PR de XCUITest en iPad, toca `YalaUITests/`). El encargo no declara `depende:` ⇒ no se espera: fetch + rebase una vez antes de abrir el PR.
- **«iOS 27» = iOS 27.2**, el único runtime de la Mini desde Xcode 27.2. Los tickets midieron en 27.0: cada rojo se re-mide antes de arreglar.
- **«iPhone SE»** = simulador `YalaLane-Adapt-iPhone-SE` (SE 3.ª gen, iOS 27.2), creado para esta sesión y borrado al cerrar.
- **Criterio de hecho, cómo se mide:** cada caso de las cinco cards, 3 corridas seguidas verdes en el SE y 3 en el iPhone 17 Pro (los dos 27.2), y 3 corridas del lote (las seis clases de la card del paywall + todas las tocadas). Una build compartida (`build-for-testing`) y `test-without-building` por destino; todo bajo `sim-lock` y centinela.
- **Arreglos en el test, no en el producto,** salvo que la medición diga que el producto pierde algo (p. ej. el importe del enlace al Panel): eso sería pregunta.
