Yala
# Tres cuelgues de producción: aplicar cambios de la nube, recalcular el Panel y la regresión del congelamiento
---
card: tablero-la-app-se-cuelga-del-todo-al-aplicar-cam-9a98
toca: Yala/Services/CloudSync/SyncApplyEngine.swift, Yala/Services/CloudSync/EntityApplyMap.swift, Yala/App/ViewModels/PanelViewModel.swift, Yala/Utils/ProfileImageStorage.swift, YalaTests/ProfileImageDownsampleTests.swift, YalaTests/SentryHangs2026Nov/, tickets/backlog/production-hangs-cloud-apply-panel-recalc-freeze.md, tickets/done/production-hangs-cloud-apply-panel-recalc-freeze.md
esfuerzo: high
cierre: cierra-sola
---

Lote de tres cuelgues de Sentry en producción (build distribuida 2.2 (9)), con el GO de Jürgen del 13-nov. Rama base: 2.3; la 2.2 está cerrada. Los tres saltaron el 12-nov por la tarde, en el mismo iPhone14,7 con iOS 27.2 y en la misma apertura de la app. Lee cada card: tienen el stack y el enlace al issue.

1. `tablero-la-app-se-cuelga-del-todo-al-aplicar-cam-9a98` · YALA-IOS-J. El apply de una página de la nube busca registros uno a uno en el hilo principal (`SyncApplyEngine.applyPage` › `EntityApplyMap.findTransactionItem` › `fetchFirstOrThrow`). Que no bloquee el hilo principal: búsqueda por lotes o fuera del hilo principal, sin cambiar lo que se aplica.
2. `tablero-el-panel-traba-la-app-al-recalcular-sus-0jkn` · YALA-IOS-K. `PanelViewModel.scheduleRecalculation` › `loadData` › `performAndWait` en el hilo principal. Que el recálculo no trabe la app.
3. `tablero-la-app-se-congela-por-completo-varios-se-ejeb` · YALA-IOS-A, regresión. Ya se arregló la foto de perfil (PR 827 y PR 875). Mide si volvió a pasar por la foto o por otra causa, por ejemplo la misma carga de J y K en esa apertura, y arréglalo de raíz.

Si Sentry no deja leer el detalle (el conector dio 403 antes), usa el correo de Sentry a admin@yala-app.pe o mide en el dispositivo. `CloudSyncEngine.swift` lo está tocando otra sesión: si de verdad necesitas cambiarlo, que sea mínimo, y lo anotas.

**Pruebas:** reproduce con una cuenta con muchos registros y grupos. Mide en el iPhone 14 por DeviceMCP, conectado a la Mini, el tiempo del hilo principal antes y después; si la Mini o el iPhone están ocupados, usa un segundo simulador. Agrega tests que caigan sin el arreglo, en `YalaTests/SentryHangs2026Nov/`. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR.

**Entrega:** un PR contra 2.3, mergeado si CI pasa, el ticket en done, las tres cards en QA y los issues marcados como resueltos en la próxima versión en Sentry. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (modo semi, decisiones técnicas): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (árbol de la 2.2 publicada, tag `v2.2`): J cuelga en `findTransactionItem` dentro del bucle de
`applyPage` (`SyncApplyEngine.swift:343` → `CloudSyncEngine.swift:3460` `try body()`); K cuelga en el `fetch` de TODOS los
movimientos de `PanelViewModel.loadData` (`:482`). Ningún `@Model` declara `#Index`: cada búsqueda por `syncID` es un recorrido
entero de la tabla, y una página de 500 deltas hace varias por delta (fila, refs, danglers, reloj por unidad, identidad).

**D1 · Cómo se quita J del hilo principal** → búsquedas por LOTE por página: antes del bucle se leen de una vez, con un
`IN`, las filas de la página por tipo (y relojes, identidades, danglers y destinos de refs), y el bucle consulta ese mapa.
Lo que la página inserta o borra se apunta en el mapa en el mismo sitio donde se inserta o borra. Una búsqueda fuera del
mapa sigue yendo al `fetch` de siempre. Por qué: cambia el coste de O(deltas × filas) a O(tablas) sin cambiar qué se
aplica ni la atomicidad de la página (D-5). Alternativas descartadas: mover el apply fuera del hilo principal (el motor es
`@MainActor` y comparte el `mainContext`; reescribirlo es otro proyecto y toca `CloudSyncEngine.swift`, que lleva otra
sesión) y añadir `#Index` (cambio de schema con espejo de CloudKit: migración y despliegue aparte).

**D2 · Qué pasa si la lectura por lote falla** → lanza, y la página hace rollback como hoy («no pude leer» nunca es «no
hay nada», regla de `swiftdata-cloudkit.md`). Por qué: un mapa vacío por error crearía born-remotes duplicados.

**D3 · Cómo se arregla K** → la recarga del Panel deja de pedirse por cada ráfaga de la sincronización: lo que avisa de
cambios remotos se suma en una sola recarga. Detalle concreto tras medir quién dispara la recarga en esa apertura; si la
lectura de todos los movimientos sigue siendo el coste dominante, se acota también ahí. Alternativa descartada: quitar la
lectura de todos los movimientos (la tendencia y el saldo la necesitan entera, comentario del propio `loadData`).

**D4 · A (regresión del congelamiento)** → primero se mide si la foto de perfil volvió a entrar por algún sitio (grep de
`UIImage(data:` y de los lectores de `ProfileImageStorage`). Si no, A se da por la misma carga de J+K en esa apertura
(mismo aparato, mismo minuto, stack sin código propio) y se cierra con esos dos arreglos y un test que mida la apertura.

**D5 · Tests** → en `YalaTests/SentryHangs2026Nov/`, con testigos deterministas (cuántas lecturas hace una página), no con
tiempos: un umbral de milisegundos sale rojo o verde según la máquina. Los tiempos van al PR como medida.

**D6 · Medir en el iPhone 14** → si la Mini o el iPhone están ocupados, simulador propio en la Max (creado hoy: la Max no
tenía ninguno). La medida antes/después del apply se hace con el banco de la suite, que es el mismo código.

**D7 · `CloudSyncEngine.swift` y `SyncUnitClock.swift`** → no se tocan salvo que el lote lo exija; si hace falta, el
cambio mínimo y anotado.
