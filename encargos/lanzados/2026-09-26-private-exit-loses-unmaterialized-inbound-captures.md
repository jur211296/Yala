# Un pago Apple Pay o un gasto de Siri no se pierde al cerrar sesión privada antes de materializarlo

## Contexto
Ticket `tickets/backlog/private-exit-loses-unmaterialized-inbound-captures.md` (léelo entero). Cola A de Yala (riesgo real: pérdida silenciosa de datos). Residual del paso 9 (`session-exits-one-verb-per-session`).

En sesión privada, las capturas de Apple Pay, Siri e imágenes compartidas esperan en colas del App Group hasta que la app las convierte en borrador. No pasan por SwiftData, así que no están en iCloud. El boot-wipe del cierre (`AppGroupInboundPurge.purgeInboundSurfaces` dentro de `performSignOutWipeIfArmed`) las borra —frontera correcta de privacidad entre cuentas—, pero en sesión privada quien vuelve suele ser la misma persona. La espera del export (`PersonalExportPendingCounter`) solo mira el historial del store: esas capturas no cuentan, el aviso de salida de emergencia no las nombra, y se pierden.

Además, con el wipe ya armado en `.icloud`, el handler de cambios remotos de `AppBootstrapper` sigue drenando esas colas hacia el store que el arranque va a borrar: solo `handleBecameActive` mira `isSignOutWipeArmed()`.

## Que se pide
1. En el cierre privado, materializar las colas del App Group ANTES de la espera del export, para que viajen como cualquier otro cambio y el contador las vea.
2. El mismo guard `isSignOutWipeArmed()` en el drenaje del handler de cambios remotos (ningún camino drena al store condenado).
3. Tests de las dos direcciones (materializa antes del export; con wipe armado no drena). Mutante que vuelva a purgar sin materializar → test en rojo.
4. Si la review saca bugs o decisiones nuevas → ticket propio antes de cerrar.

## Que NO hay que tocar
- El cierre de la nube y la frontera M1: siguen purgando sin materializar (privacidad entre cuentas).
- El ticket diferido `sign-out-exits-do-not-verify-the-cloud-session-closed` (sigue «sin prisa»).
- `late-icloud-wipe-can-re-export-between-its-two-halves` (espera el mecanismo de relanzamiento del rediseño).
- `mcp/`, staging/prod de Supabase, marketing/, Cola B (rediseño UI).

## Como se sabe que esta bien
- Una captura pendiente se convierte en borrador antes de que el cierre privado cuente lo pendiente.
- Con el wipe armado, ningún camino drena las colas al store condenado.
- Gate verde; review adversarial del diff; PR a `2.1` mergeado; ticket a `qa` o `done` con guion si hace falta device; `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO
La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa hasta gate/PR/merge y cierra con `/cerrar-total` sin pedir continuar. Solo AskUserQuestion real de producto/acceso (es de día Lima). Decisiones de techos/copy/salidas: elige la opción robusta/Recommended tú.

## Paso 0 (Frank, 2026-09-26)

Ficheros (nota, no pregunta — MODO AUTÓNOMO):
- `Yala/App/Services/InboundCaptureDrain.swift` (nuevo): el único que drena Apple Pay + Siri al store, con el guard `isSignOutWipeArmed()` dentro.
- `Yala/App/AppBootstrapper.swift`: arranque, `handleBecameActive` y el trailing edge del remote-change drenan por el helper.
- `Yala/App/Logic/PrivateSignOutExportGateLogic.swift`: composición pura «materializa → cuenta historial + lo que siga en cola».
- `Yala/Services/CloudSync/CloudSessionSignOut.swift`: cada recuento del cierre (espera, re-aviso, recuento pegado al arm) materializa antes.
- `Yala/Services/CloudSync/AppGroupInboundPurge.swift`: header al día.
- Tests nuevos + `qa/coverage-index.json` + regla de área + ticket.

Decisiones (auto-contestadas):
1. **Qué cierres materializan: los que esperan al export** (C y D salvo «sin copia», F con espejo). Donde no se espera no hay a dónde subir: materializar solo movería la captura a un store que muere igual. La nube y M1 no se tocan.
2. **Dónde: dentro de cada vuelta del recuento**, no una vez al principio. Así también entra lo capturado durante la espera y un reintento tras el import.
3. **Si la cola no se puede materializar** (import activo → el gate de quiescencia difiere): **cuenta como pendiente**. La espera no confirma cero y, si se agota, el aviso la incluye en la cifra. Nunca se borra callada.
4. **Imágenes compartidas: fuera.** No se pueden convertir en borrador sin la persona (análisis IA + consentimiento), el original sigue en la app de origen y ya caducan a las 24 h. Contarlas bloquearía cada cierre hasta la salida de emergencia.
5. **El guard va DENTRO del escritor** (helper único), no repetido en cada llamador: el arranque, el foreground y el remote-change pasan por él; un source-scan fija que nadie más llama a `processPending`.
6. **Sin ancla, el recuento cacheado se invalida si se creó un borrador**: el cero cacheado ya no es verdad.
