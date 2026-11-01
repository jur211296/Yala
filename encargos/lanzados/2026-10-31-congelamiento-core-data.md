---
esfuerzo: high
release: no
---
# La app deja de congelarse por Core Data en el hilo principal

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `congelamiento-core-data` · Sesión cola **S35o** · al cerrar → **S35p** (`ci-tests-en-verde`).

## Contexto
Jürgen aprobó este plan el 31-oct a las 22:03 (Lima): «Sí, aplícalo así». Su regla del 2026-10-30 es que todo entra en 2.2 antes del barrido QA, nada a backlog.

Zona: el arranque y las pantallas que leen Core Data en el hilo principal (ver la traza de Sentry YALA-IOS-2).

Cards:
- `tablero ver tablero-la-app-se-congela-varios-segundos-por-co-yh9g` — La app se congela varios segundos por Core Data en el hilo principal (Sentry YALA-IOS-2)
  - Problema: Sentry reporta un cuelgue de la app (App Hang, primero «Fully Blocked» y luego «Non Fully Blocked») en producción con el build 2.2 (5) de TestFlight. 6 ocurrencias entre 2026-10-30 16:24 y 18:17 hora de Lima, en un iPhone19,3 con iOS 27.2, app en primer plano. El stack del hilo principal muestra NSManagedObjectContext.performAndWait → NSPersistentStoreCoordinator executeRequest → NSSQLPersistentHistoryChangeRequestContext / hasHistoryTransactionWithNumber: una consulta de historial persistente de Core Data (probablemente CloudKit/NSPersistentCloudKitContainer) bloqueando el hilo principal. Hipótesis a verificar: un performAndWait síncrono sobre el viewContext o una lectura de persistent history en el main thread. Seer la marca de accionabilidad baja porque no hay frames propios simbolizados (falta subir dSYM).
  - Hecha cuando: Causa encontrada, arreglo con test, y el issue YALA-IOS-2 resuelto en Sentry.

## Qué se pide
1. Lee cada card y su ticket, si tiene. Busca la causa raíz antes de tocar código.
2. Cumple el «hecha cuando» de cada card, con tests (unitarios, source-scan o XCUITest según el caso) y, si es visual, vídeo o capturas antes y después en `capturas/` y en el digest.
3. Pasa las cards a «in qa» de Jürgen al abrir el PR (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Nada fuera de las cards de esta sesión.
- marketing/ ni Web/ (salvo el README de marca, si está en las cards).
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Cada card cumple su «hecha cuando».
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** Los 6 eventos de YALA-IOS-2 (2.2 (5), un solo iPhone19,3, 30-oct 16:24–18:17 Lima)
salen de un job async en el hilo principal (`runJobInEstablishedExecutorContext` → código de Yala → SwiftData). Dos caen
dentro de un `fetchHistory` por token (`hasHistoryTransactionWithNumber`, y el `encode` del token en el predicado); cuatro
en código de Yala manejando modelos de SwiftData (retain/release, `getObjectType`). El último llega tras más de un minuto de
`POST sync/push` cada ~6,6 s. Los frames de Yala no se pueden simbolizar: ASC no tiene dSYM del build 5 y un Release
reconstruido no coincide (UUID y tamaño distintos). El drenaje de sync —personal (`CloudSyncEngine.performDrain`) y de
Grupos— es `@MainActor` y síncrono, corre en cada ciclo (60 s, tras cada descarga, en cada página de la subida de la
migración) y **en cada vuelta carga e indexa todas las filas** de 16 tipos personales (4 de Grupos) antes de mirar si el
History trae algo.

**D1 · ¿Dónde está la causa?** → En el drenaje: el barrido completo de modelos y las lecturas del History en el hilo
principal, en cada vuelta, también cuando no hay nada nuevo.
Por qué: casa con las dos familias de stack y con la cadencia de `sync/push`. Alternativa descartada: «solo el
`fetchHistory`» — no explica los cuatro stacks sin `performAndWait` de historial.

**D2 · ¿Sacar el drenaje del hilo principal (ModelActor)?** → No. Se recorta lo que hace en el hilo principal.
Por qué: el motor entero es `@MainActor` por regla del repo (ModelContext + @Model) y moverlo toca toda la sync, que es
justo donde un bug sale caro. Alternativa descartada: actor de fondo — refactor enorme y fuera del alcance de la card.

**D3 · ¿Qué se recorta?** → El índice persistentID→modelo se construye **solo para los tipos que tocan las transacciones
de la ventana** (las que se traducen: no del motor, del store, entidades sincronizables). Ventana vacía ⇒ cero fetches de
modelos. El guardado de lo pendiente que hacía el barrido se conserva ANTES de leer el History (lo que el rollback del paso
6 presupone). En los caminos raros (token ausente o roto) se mantiene el barrido completo de siempre.
Por qué: cada índice solo lo consulta su propia entidad, y el `syncID` de una fila nueva se sigue acuñando porque su insert
está en la ventana. Alternativa descartada: saltar solo con ventana vacía — deja el barrido entero tras cada descarga.

**D4 · ¿Grupos también?** → Sí, el mismo recorte en su drenaje, que repite el patrón (4 tipos).
Por qué: el usuario no distingue qué canal congela; «buscar todas las instancias». Alternativa descartada: dejarlo para otra card.

**D5 · ¿Cómo se prueba?** → Unit tests con un testigo de qué tipos indexó la vuelta (vuelta sin cambios = ninguno; un
gasto nuevo = solo `TransactionItem`, y sale su fila) + la batería existente del drenaje en verde + medida de tiempo con
miles de filas antes/después en el informe (no como aserción: sería frágil).

**D6 · Resolver YALA-IOS-2 y subir dSYMs.** → No se puede desde aquí: solo hay token de lectura de Sentry (el del Llavero
`sentry-yala` no existe) y no hay `sentry-cli` ni paso de subida de dSYM en el release. Card `cierra-sola` a jurgen: resolver
el issue en la próxima versión y dar el token para montar la subida de dSYM.
Por qué: es una credencial que no tengo. Alternativa descartada: marcarlo resuelto a mano — no puedo y sería prematuro
antes de que el arreglo llegue a un build.

**D7 · Review adversarial** → Sí: es lógica de sync donde un bug pierde datos.
