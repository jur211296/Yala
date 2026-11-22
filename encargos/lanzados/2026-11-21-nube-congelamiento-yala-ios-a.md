Yala
# Congelamiento tras guardar con la nube: medir y quitar la doble recalculación (YALA-IOS-A y YALA-IOS-13)
---
toca: Yala/Services/CloudSync/CloudSyncEngine.swift,Yala/App/AppBootstrapper.swift,YalaTests/NubeCongelamiento/,tickets/backlog/2026-11-21-nube-congelamiento-yala-ios-a.md,tickets/done/2026-11-21-nube-congelamiento-yala-ios-a.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen aprobó el 21-nov (08:39 Lima, decisión t1868-reconfirma; decisión 145 de la auditoría `docs/auditorias/2026-11-21-decisiones-vs-2-3.md`, artifact https://claude.ai/artifact/VfRj9Xg1ufZP8uZpPaD972) encargar este pendiente. Decisión t1822u (20-nov): «Jürgen autoriza encolar los cuelgues nuevos de Sentry de la build 2.3: congelamiento al aplicar cambios de la nube…». La auditoría lo marca como no resuelto en 2.3. Cards existentes: «La app se congela por completo varios segundos · YALA-IOS-A», «Tras guardar con la nube activa, la app se recalcula dos veces (resto de YALA-IOS-A)» y «La app se congela por completo al aplicar cambios de la nube · YALA-IOS-13». Antes de tocar nada, confirma con `git log origin/2.3` y el código qué parte ya quedó resuelta (hubo un PR de sincronización de congelamientos al aplicar cambios).

## Qué hacer
1. Reúne evidencia en Sentry con el MCP de Sentry (YALA-IOS-A y YALA-IOS-13): stack, hilo y duración. Sin imprimir secretos.
2. Mide el estado actual en Instruments (Hangs/Time Profiler) o con signposts: segundos de bloqueo del hilo principal al guardar con la nube activa y número de recalculaciones por guardado.
3. Corrige la causa: saca el trabajo pesado del hilo principal y junta las dos recalculaciones en una sola.
4. Mide después con el mismo escenario y compara.
5. Agrega pruebas en `YalaTests/NubeCongelamiento/` que fallen sin la corrección.
6. Mueve las tres cards según lo que quede resuelto.

## Criterios de aceptación
- Al guardar con la nube activa, el hilo principal no se bloquea más de 250 ms en el escenario medido.
- Una sola recalculación por guardado, demostrada con signposts o un contador en pruebas.
- Medición antes y después en el artifact, con capturas.
- `tests`, `coverage-index` y `gateway` en verde.

## Cómo verificar y entregar
- Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP.
- Capturas antes y después en el cierre.
- La entrega visual se hace como artifact de Claude.
- Trabajo solo en tu rama de encargo; no toques archivos que no estén en `toca:`.

Antes de cambiar código: las cards de YALA-IOS-A y YALA-IOS-13 están en «in qa» porque una sesión anterior ya trabajó en esto. Primero mide en 2.3 actual (Sentry de los últimos días y una reproducción con la nube activa) si el congelamiento o la doble recalculación siguen. Si ya no se reproducen, no rehagas nada: deja la evidencia en el cierre y termina.

Índices compartidos: `docs/TICKETS.md` y `qa/coverage-index.json` no van en `toca:`; edítalos solo al final, justo antes del PR, tras `git rebase origin/2.3`, resolviendo por fila o área sin pisar lo de otra sesión.

Termina con /cerrar-total cuando el PR esté dentro de 2.3.
## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, sesión nocturna): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (21-nov, 22:00 Lima):
- La parte de YALA-IOS-13 (pase de refs colgadas) ya está resuelta en 2.3 (PR «Sin congelamientos al aplicar cambios de la nube», 20-nov). YALA-IOS-A y YALA-IOS-13 figuran resueltos en Sentry, sin eventos desde el 20-nov 06:45 Lima.
- Pero en la misma apertura del último evento de A (build 2.3 (5), iPhone personal) saltaron YALA-IOS-14, 15 y 16, con pila propia: recálculo del Panel (tendencia), proyección del Flujo de caja y foto de los widgets, 1-3 s después de `push → pull`. YALA-IOS-17 es el cuelgue de prueba de Sentry (build dev), no cuenta.
- La doble recalculación sigue en el código: el pull devuelve el eco de lo que el teléfono acaba de subir, el apply lo cuenta como página aplicada y `fanOutRemoteChangesApplied` sube `dataVersion` (desde el 13-nov, en el acto con la app delante) → todas las pantallas recalculan por segunda vez.

**D1 · ¿Se rehace o se cierra con evidencia?** → Se arregla: la doble recalculación se reproduce en el código de 2.3.
Por qué: el encargo pide no rehacer solo si ya no se reproduce, y se reproduce. Alternativa descartada: cerrar con evidencia de Sentry (dos issues «resueltos» no prueban nada: los cuelgues siguieron con otro título).

**D2 · ¿Cómo se junta en una sola recalculación?** → El ciclo de la nube solo avisa a la app si el pull cambió algo; el eco de lo propio (cada parte de la fila llega con el mismo HLC que este teléfono ya tiene en `SyncUnitClock`) no cuenta. Los datos se siguen aplicando exactamente igual.
Por qué: es la causa, y no toca el camino de los datos. Alternativas descartadas: filtrar el eco en el servidor (cambia el gateway y su Merkle, fuera de alcance de noche); no aplicar el eco (ahorra poco y arriesga divergencias si el servidor normaliza un valor); un debounce de la UI (tapa el síntoma y retrasa cambios reales de otro aparato).

**D3 · ¿Qué cuenta como «cambió algo»?** → Fila nueva, fila borrada, una parte aplicada cuyo HLC remoto difiere del local (o sin reloj local), cuarentena, una ref colgada resuelta o un reconciliador que guardó. Una parte sin HLC remoto no decide (nadie la escribió nunca). En la duda, cuenta como cambio.
Por qué: falla hacia avisar de más, que es el comportamiento de hoy.

**D4 · ¿Se saca trabajo pesado del Panel, del Flujo o de los widgets?** → No en este encargo. Se anota como hallazgo con card.
Por qué: `toca:` no los incluye, el encargo pide «solo los cambios pedidos», y quitar la segunda recalculación ya elimina el bloque repetido tras guardar. Alternativa descartada: arreglar también la ordenación del Flujo (`FlujoProyeccionInteligente.detectar` describe un `PersistentIdentifier` dentro del comparador de un `sort`, YALA-IOS-15), que merece su propio encargo con medición.

**D5 · Ficheros fuera de `toca:`** → Se tocan `Yala/Services/CloudSync/SyncApplyEngine.swift` (el apply) y `CloudSyncRuntime.swift` (el aviso), además de `CloudSyncEngine.swift`. `AppBootstrapper.swift` no hace falta.
Por qué: ahí vive el mecanismo; `turno_merge.py ver` no muestra otra sesión de Yala ni PR abiertos que los toquen.

**D6 · ¿Cómo se mide sin una cuenta de la nube en el simulador?** → Con una prueba de integración del ciclo real (`CloudSyncRuntime.syncCycle`) contra un servidor falso que devuelve lo subido, contando avisos y recargas del Panel, y midiendo el bloque más largo del hilo principal del recálculo del Panel con un historial grande. Lo inferido (coste en el iPhone) se separa de lo medido.
Por qué: activar la nube de staging en el simulador de noche pide credenciales y una cuenta de prueba; el iPhone 14 se usa solo si está libre. Nada en producción.

**D7 · ¿El canal de Grupos tiene el mismo eco?** → Fuera de alcance: se anota en «Encontrado» con card.
Por qué: `GroupsSyncClient` es otro canal y otro fichero; un gasto personal no pasa por él.
