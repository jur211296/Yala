# Tras vaciar los datos desde otro dispositivo, el widget, Siri y los recordatorios siguen mostrando datos del dueño

## Contexto
Card del tablero `tablero-tras-vaciar-los-datos-desde-otro-disposi-pb6r` (in progress frank, prioridad high, vence 2026-10-12). Ticket: `tickets/backlog/after-session-redesign-review-widgets-siri-applepay-and-web-copy.md` (triage medium 2026-10-08 → high). Brief: `~/Claude/entregas/2026-10-08-triage-tickets-medium-nueva-escala/after-session-redesign-review-widgets-siri-applepay-and-web-copy.md`.

CADENA nocturna tras cerrar `queued-offer-after-dismiss-flakes-on-a-cold-simulator` (PR #412 en cola de auto-merge a 2.1; card h411 done; sin QA manual). Alternación Cola A ↔ adaptive/lista: toca este high de producto (widget/Siri/recordatorios tras wipe remoto).

Hoy, en un teléfono prestado, el dueño puede vaciar sus datos desde otro dispositivo y el borrado llega por el espejo de CloudKit. Después, la pantalla de inicio sigue enseñando su saldo y últimos movimientos; Siri sigue ofreciendo sus subcategorías; los recordatorios de pagos programados siguen llegando. Hay que limpiar esas tres superficies con el vaciado remoto. Además, el widget de una sesión de solo grupos debe invitar a activar Yala completo (decisión Jürgen 2026-09-09). El resto de la lista del ticket se mide de paso: Apple Pay y Siri en cola con sesión de solo grupos, exportación por celda y `coverage-index`.

**Disco Mini ~29 GB libres (umbral 32).** Antes de construir: limpia agresivo DerivedData de sesiones cerradas, cachés XcodeBuildMCP de worktrees retirados, sims muertos/basura. Evita tandas grandes de capturas de widgets (una captura cuesta ~10 GB); usa el mínimo de evidencia (test de comportamiento + 1 captura del widget solo-grupos si hace falta). Si el disco baja de ~20 GB, para, limpia y continúa sin capturas extra.

Pistas (verifícalas en este árbol):
- `Yala/App/ContentView.swift`: `startFreshAfterRemoteWipeNotice` y `handleRemoteWipeSignal` — falta la limpieza.
- `Yala/Services/WidgetDataCache.swift`: `clearCache()` y su puerta (espejo de `NotificationService.isPersonalWipeArmed`).
- `Yala/Services/CloudSync/AppGroupInboundPurge.swift`: `purgeInboundSurfaces()` — único que llama a `SiriIntentContextCache.clear()`.
- `Yala/Services/NotificationService.swift`: `cancelAllNotifications()` / `isPersonalWipeArmed`.
- Molde: `Yala/Services/CloudSync/SecondarySessionRetirement.swift` (`purgeSharedSurfaces`).
- `YalaWidgets/` para la vista «aún no hay finanzas personales».
- Relacionado: `remote-wipe-receiver-has-no-behaviour-test` (por qué hoy no hay seam).

Gate post-CI del PR anterior: justo antes del gate, mira si el PR #412 (queued-offer-after-dismiss) sigue en CI. Si sigue, espera a que entre y rebasea una sola vez con el simulador apagado sobre `origin/2.1`. Si `2.1` no se movió, sigue. Si ese CI falla, no esperes: rebasea con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez. Base actual al lanzar: `da5efd6fb` (merge #411); #412 aún OPEN con `tests` IN_PROGRESS y auto-merge.

Pipeline serial Mini (obligatorio): (1) limpiar sims muertos/basura/DerivedData de sesiones cerradas/cachés XcodeBuildMCP de worktrees retirados; (2) `xcodebuild -jobs 2` sin sim booteado; (3) boot 1 sim; (4) tests; (5) apagar/limpiar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma: 1 simulador a la vez.

Antes de tocar UI: `~/Claude/referencias-ui/README.md` y `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Reproducir / demostrar el hueco: tras señal de wipe remoto, widget cache, SiriIntentContextCache y notificaciones locales NO quedan limpios con el código de hoy.
2. En `startFreshAfterRemoteWipeNotice` y `handleRemoteWipeSignal`, limpiar las tres superficies con el molde de `purgeSharedSurfaces` (o el camino equivalente correcto). Cubrir rama «Empezar de cero» del aviso y rama sin aviso.
3. Test de comportamiento del receptor del wipe remoto: tras la señal, caché del widget vacía, SiriIntentContextCache limpia, cero notificaciones locales pendientes. Control que sale rojo con el código de hoy.
4. Widget en celda de solo grupos: texto que invita a activar Yala completo (decisión 2026-09-09). XCUITest o 1 captura mínima.
5. Medir de paso (sin hinchar alcance): Apple Pay y Siri en cola con sesión solo-grupos; exportación por celda; `coverage-index` si aplica. Ticket/residual si algo queda fuera.
6. Device-QA para Jürgen: guion en `tickets/qa/` — teléfono prestado, vaciar desde el otro, comprobar widget vacío y sin recordatorios del dueño. Card a **in qa → jurgen** si queda device-QA; si el test automatizado cubre el criterio y no hace falta device, **done → frank**.
7. Textos nuevos en los 16 idiomas con `qa/scripts/add-l10n-key.sh`, español neutro latinoamericano.
8. Anota lo resuelto en el ticket; muévelo según convenciones del repo; tablero al día.
9. Al terminar: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card bien puesta, limpiar worktree/tmux/DerivedData/cachés XcodeBuildMCP de este worktree, sin sims).

## Que NO hay que tocar
- No abrir más de 1 simulador.
- No tandas masivas de capturas de widgets (disco).
- No tocar clinicas ni secretos nuevos en el Llavero sin subirlos a 1Password al cerrar.
- No pedir créditos ni claves nuevas.
- No reabrir el trabajo de PR #412 salvo rebase sobre 2.1.

## Paso 0

Medido en este árbol (`da5efd6fb`) antes de escribir código:

- **Rama de la señal** (`handleRemoteWipeSignal` → `DataWipeService.wipeLocallyForRemoteWipeSignal` → `wipeAllUserData`): el
  widget YA se vacía (PASO 3, `WidgetDataCache.clearCache()`) y los avisos YA se cancelan (`deleteNotifications` →
  `cancelAllNotifications`) y se reprograman los que sobreviven al corte. **Solo falta Siri**: `SiriIntentContextCache.clear()`
  tiene un llamador (`AppGroupInboundPurge`, cierres de sesión).
- **Rama «Empezar de cero» del aviso**: no limpia ninguna de las tres. El widget solo se reescribe en el arranque en frío, en
  tareas de fondo o tras una edición; Siri en el siguiente primer plano; los avisos pendientes de pagos y resúmenes siguen.

Decisiones (autónomo; ninguna es de producto nueva):

1. **Señal: Siri entra en el PASO 3 de `wipeAllUserData`, junto al widget**, no en `ContentView`. Es el choke-point de todo
   borrado de filas personales; el mismo hueco existe en «Vaciar datos» y en los borrados del Welcome/aviso tardío, y el
   snapshot vacío es un estado esperado del intent (`read() == nil`). **No** se añade otro `cancelAllNotifications()` en esa
   rama: correría contra la reprogramación de los recordatorios que sobreviven al corte.
2. **«Empezar de cero»: helper nuevo `RemoteWipeSharedSurfaces`** (molde `purgeSharedSurfaces`): widget, snapshot de Siri,
   avisos pendientes y las marcas del resumen diario de pagos (si no, «este día ya tiene resumen» mentiría tras cancelar).
   Las de avisos ya entregados se quedan (corrección de la review: barrerlas repetía banners si las filas vuelven). **No** las colas de Apple Pay/Siri ni los avisos ya entregados: son capturas y avisos de este teléfono, no una
   frontera de cuenta.
3. **«Ahora no» no limpia**: los datos pueden volver y el aviso vuelve si siguen fuera.
4. **Widget en solo grupos: clave propia del App Group** (`widget_groupsOnlySession`), **no un campo del snapshot**: un campo
   Codable nuevo en el DTO duplicado apaga todos los widgets si se equivoca. La escriben `WidgetDataCache.updateCache` (cubre
   la actualización de versión) y el `didSet` de `SessionState.hasPrivateSession` (el único embudo del eje). Lectura laxa del
   eje (como la shell): sin marca no se invita.
5. Vista de invitación única en el widget, aplicada a todos los widgets de datos (no a los de entrada rápida), con enlace
   `yala://activate-full` que en solo grupos abre «Activar Yala completo» y si no, el Panel.
6. Tests: comportamiento del helper con stores aislados + caso real de `wipeLocallyForRemoteWipeSignal` sobre el snapshot de
   Siri (rojo con el código de hoy) + scans del cableado; mutantes para cada uno.
7. Evidencia visual: 1 captura del widget en solo grupos solo si el disco lo permite (> 22 GB).
