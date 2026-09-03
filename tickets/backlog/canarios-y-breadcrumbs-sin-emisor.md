---
id: canarios-y-breadcrumbs-sin-emisor
status: backlog
priority: medium
area: qa
created: 2026-09-02
updated: 2026-09-02
---

# Hay 19 señales de vigilancia que no las emite nadie, y dos tickets las usan como prueba de que todo va bien

## Qué pasa

Esto no lo sufre quien usa la app — todavía. Lo sufre quien abre el dashboard dentro de seis meses,
ve un contador en cero y concluye que el sistema está sano. **Está en cero porque nadie lo escribe.**

El daño llega al usuario por el camino largo: un fallo que teníamos instrumentado deja de avisarnos,
nadie lo ve en la flota, y el primero en enterarse es la persona a la que se le rompe algo. Ya pasó
una vez con el atajo de Siri (ver abajo) y hoy volvería a pasar igual.

**Lo grave no son las señales muertas.** Un contador huérfano es basura, molesta poco. Lo grave es que
**hay criterios de aceptación escritos hoy que se apoyan en ellas** en forma de «este contador debe
estar a 0». Ese criterio pasa siempre. Es peor que no tener criterio, porque da la sensación de haber
verificado algo.

## Los criterios que hoy no pueden fallar

Medido contra `HEAD 553b91c9` (rama `2.1`, 2026-09-02):

1. **`tickets/blocked/groups-join-intent-reconciler.md`, en su lista de telemetría** —
   «`cloudkitGroupEnqueueDroppedNoEngine` debe ser 0». Ese canario tiene **cero emisores** en todo el
   árbol. El propio ticket ya lo marcó como obsoleto en su re-medición del 2026-08-17 (aparece en la
   lista de premisas caídas), pero **la línea del criterio sigue en pie sin tachar**, unas líneas más
   arriba en el mismo fichero. Quien lea la sección de arriba hacia abajo se lo cree.

2. **`tickets/discarded/rescue-discarded-groups-pull.md`, sección «Qué falta (QA)»** — el punto 4 pide
   «canario en cero en el dashboard de Analytics Engine salvo en el escenario 1», y los puntos 2 y 3
   esperan ver los breadcrumbs `ckPullSkippedBackendGroup … reason=staleEcho` y `reason=replay`.
   `groupsCkPullSkippedBackendGroup` tiene **cero llamadas**, y el `ckPullRescued` que citan los puntos
   1 y 2 no llegó a existir nunca: `groupCkPullRescued` / `groupsCkPullRescued` dan **cero ocurrencias**
   en el árbol entero. Ese guion de QA no se puede ejecutar y sus tres primeros pasos no se pueden
   observar.

3. **`tickets/qa/storekit-appgroup-siri-pro-gate.md`** (status `qa`, prioridad `high`) — su paso 3 de
   QA pendiente dice «post-release: el rate de `intentFailed`/`pro_required` en TelemetryDeck debe
   caer». Es el caso peor de los tres y va aparte, más abajo.

## El barrido

Todo lo de esta sección lo he medido yo hoy contra `HEAD 553b91c9`. El árbol tenía movimientos de
ficheros bajo `tickets/` sin commitear; nada de `Yala/`, así que las coordenadas de código son las de
HEAD.

### Canarios sin emisor — 11 de 79

`enum MetricsCanary` en `Yala/Services/Metrics/MetricsService.swift`. «Sin emisor» = ninguna ocurrencia
de `.<caso>` fuera de ese fichero que no sea un comentario.

| Línea | Caso | Nota de la medición |
|---|---|---|
| 37 | `cloudkitBudgetCSVMirrorRebuilt` | Único que **no** viene de la purga de Grupos |
| 70 | `cloudkitGroupSyncGateHardCap` | |
| 71 | `cloudkitGroupSyncPromotedToAuto` | |
| 72 | `cloudkitGroupSyncNoImportPromote` | Dos comentarios en `AppBootstrapper` lo nombran; ninguno lo emite |
| 73 | `cloudkitGroupZoneRecovered` | |
| 74 | `cloudkitGroupRecordsRecovered` | |
| 75 | `cloudkitGroupRecordSaveRejected` | |
| 76 | `cloudkitGroupEnqueueDroppedNoEngine` | El del criterio 1 |
| 77 | `groupsIdentityBootMismatch` | |
| 168 | `inviteReEmittedFromStore` | Tiene wrapper typed vivo en `:398-400` que **nadie llama** |
| 169 | `invitePendingExpired` | Igual: wrapper en `:402-404`, sin llamador |

Los dos últimos son la trampa de este barrido: un `grep` del nombre devuelve tres líneas y parece que
están vivos. Las tres están dentro de `MetricsService.swift` — la declaración del caso más un wrapper
que se llama a sí mismo hacia el canario y al que no invoca nadie. **Contar ocurrencias no basta; hay
que mirar dónde caen.**

De las 46 funciones estáticas de `MetricsService`, esas dos son las únicas sin llamador (descontado
`kickDrain`, que se invoca cuatro veces sin prefijo dentro del propio fichero).

### Breadcrumbs sin llamador — 8 de 31

Todos en `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift`:

| Línea | Función | MARK |
|---|---|---|
| 160 | `groupsCkEnqueueSkippedBackendGroup` | Partición POR-GRUPO (G5-A) |
| 175 | `groupsCkMigrationMarkerEnqueued` | Partición POR-GRUPO (G5-A) |
| 184 | `groupsCkPullSkippedBackendGroup` | Partición POR-GRUPO (G5-A) — el del criterio 2 |
| 193 | `groupsCkFetchApplyFailed` | Partición POR-GRUPO (G5-A) |
| 233 | `groupsIdentityChangeRetained` | Cambio de identidad de iCloud (C-3) |
| 242 | `groupsIdentityChangePurgeFailed` | Cambio de identidad de iCloud (C-3) |
| 251 | `groupsIdentityPurgeDeferred` | Cambio de identidad de iCloud (C-3) |
| 257 | `groupsIdentityPurgeResumed` | Cambio de identidad de iCloud (C-3) |

Los otros cinco ficheros de breadcrumb (`IntentSignalBreadcrumb`, `PushBreadcrumb`, `RestoreBreadcrumb`,
`SaveBreadcrumb`, `SharedImageBreadcrumb`) están **limpios**: todas sus funciones públicas tienen
llamador real. Los dos falsos positivos que salieron en el barrido se invocan sin prefijo de tipo
dentro de su propio fichero: `PushBreadcrumb.label` (privado) y `MetricsService.kickDrain`.

### La mitad honesta y la mitad que engaña

Los cuatro breadcrumbs del MARK **«Cambio de identidad de iCloud (C-3)»** llevan encima, en el propio
código, un aviso que dice que los cuatro están sin emisor desde la Fase 3 y que un dashboard que los
espere seguirá en cero para siempre. **Ésos no mienten a nadie**: hacen exactamente lo que hay que
hacer con una señal que se conserva por su valor documental.

Los cuatro del MARK **«Partición POR-GRUPO (G5-A)»** no llevan ese aviso, y sus doc-comments los
describen en presente («el guard simétrico de pull saltó aplicar un record…») como si el guard siguiera
corriendo. Los once canarios del enum tampoco llevan aviso: son `case` a secas, sin una línea que
advierta.

La asimetría es el hallazgo transferible: alguien ya resolvió bien este problema en la mitad del
fichero y la otra mitad se quedó sin la anotación.

### Por qué murieron

Los ocho canarios de las líneas 70-77 y los cuatro breadcrumbs `groupsCk*` los emitía
`Yala/Services/Groups/SplitSyncManager.swift`, que **hoy no existe** (comprobado: el fichero no está en
el árbol). Lo borró la Fase 3 de la simplificación de Grupos, que se llevó el transporte CloudKit
entero. Los cuatro `groupsIdentity*` murieron con la purga de identidad en la misma tanda (pérdida
declarada). Los dos de invites (`inviteReEmittedFromStore`, `invitePendingExpired`) se quedaron sin
emisor cuando desapareció `PendingInviteStore` con el canal CKShare.

`cloudkitBudgetCSVMirrorRebuilt` es el único que no encaja en esa historia: **ya estaba huérfano antes**,
y así consta en la medición de julio archivada en `docs/modo-nube/_archive/fase3-medicion/`. Es un
zombi de algún borrado anterior. El compilador no lo caza porque un `case` de enum sin usar es legal.

## El caso aparte: `intentFailed`

`intentFailed` **no es una señal huérfana: no existe.** Cero ocurrencias en todo el árbol — `Yala`,
`YalaTests`, `YalaUITests`, `YalaWidgets`, `YalaShare`. No es un caso del enum `MetricsCanary` ni lo ha
sido nunca; era un evento de TelemetryDeck. Nació el 2026-04-26 (`e6430bd1`, telemetría de invocación y
outcome de los cinco intents) y murió el 2026-07-17 con la purga de TelemetryDeck (`d460480b`), junto a
los ~190 call-sites de producto que ese commit se llevó.

**Ese evento es el que detectó el bug original.** El ticket de Siri lo dice en su propia sección de
diagnóstico: la señal fue `intentFailed` con `error: "pro_required"` llegando de usuarios que sí eran
Pro. Un escritor apuntaba a un App Group que no estaba en los entitlements, el lector del gate leía del
canónico y devolvía `false` siempre, y **todo usuario Pro que invocaba el atajo recibía «necesitas
Pro»**. Estuvo roto desde abril.

Hoy ese mismo bug sería invisible. El gate sigue en el mismo sitio —
`Yala/App/Intents/QuickExpenseIntent.swift:209`, un `return` con el diálogo `proRequired` — y **no emite
nada**: en toda la carpeta `Yala/App/Intents/` no hay una sola referencia a `MetricsService`. Una
regresión idéntica no se vería hasta que la reportara un usuario.

La telemetría de hoy va a Cloudflare Analytics Engine (`POST /metrics` del gateway), no a TelemetryDeck.
El criterio «el rate debe caer en TelemetryDeck» pide mirar un panel de una herramienta retirada, una
métrica que no se emite, en un producto que ya no la manda.

## Qué hacer con cada señal — son dos decisiones distintas, no una

**Emitirla donde tocaba** y **borrarla junto con el criterio que se apoya en ella** no son la misma
decisión y no se toman igual. La pregunta que las separa: *¿sigue existiendo el fallo que esa señal
vigilaba?* Si el subsistema murió, la señal es basura. Si el subsistema vive y solo se cayó el cable,
la señal es un agujero de observación.

### A. Borrar — el subsistema no existe (12 señales)

Los ocho canarios de las líneas 70-77 y los cuatro breadcrumbs `groupsCk*`. Vigilaban el transporte
CloudKit de Grupos y la identidad de iCloud; ninguno de los dos existe. No hay dónde emitirlos. Se
borran, y **en el mismo cambio** se limpian los criterios de aceptación que los citan (el criterio 1 y
las cuatro menciones del criterio 2) y las tres citas del área `groups-cross-device-sync` en
`qa/coverage-index.json` — su campo `coverage` nombra hoy `cloudkitGroupEnqueueDroppedNoEngine`,
`groupsIdentityBootMismatch` y `cloudkitGroupSyncPromotedToAuto` como si fueran cobertura viva
(`classification: manual`, `lastVerified: 2026-08-11`).

Los cuatro `groupsIdentity*` pueden quedarse si se quiere conservar el porqué escrito: **su aviso ya
hace el trabajo**. Lo que no puede pasar es que alguien vuelva a citarlos como criterio.

Alternativa más barata y casi igual de buena para los cuatro `groupsCk*`: no borrarlos y copiarles el
aviso que ya tienen sus vecinos del MARK de identidad. Decide quien lo haga.

### B. Decidir de verdad — el subsistema cambió de forma (3 señales)

Éstas no son borrado automático. Hay que contestar una pregunta antes:

- **`inviteReEmittedFromStore` / `invitePendingExpired`** — vigilaban que una invitación pendiente no se
  perdiera. El canal CKShare que las emitía murió, **pero las invitaciones siguen existiendo** por el
  canal backend. La pregunta es si el fallo equivalente puede darse hoy y merece señal propia. Si sí,
  se re-cablean al camino nuevo; si no, se borran ellas y sus dos wrappers.
- **`cloudkitBudgetCSVMirrorRebuilt`** — vigilaba la reconstrucción del espejo CSV de un presupuesto,
  y su hermano `budgetFiltersAppearEmpty` (que sí tiene emisor vivo, en `BudgetsViewModel`) cubre el
  síntoma que ve el usuario: **abre un presupuesto y sus filtros salen vacíos**. Hay que mirar si el
  camino de reparación existe todavía y quedó mudo, o si desapareció. **No lo he medido** — hace falta
  leer el backfill de presupuestos antes de decidir.

### C. Reponer — el fallo sigue vivo y nos quedamos ciegos (1 señal)

`intentFailed`. Aquí no vale borrar el criterio y seguir: el gate Pro del atajo sigue en producción y
sigue pudiendo romperse igual. Dos salidas:

- **Reponer la señal.** Un caso nuevo en `MetricsCanary` emitido en el `return` del `proRequired`.
  ⚠️ **Infiero** (no lo he medido) que no es una línea: `MetricsService` es no-op sin `start()`, y el
  único que lo arranca es `AppBootstrapper`, que no corre en el proceso del intent. La vía sería el
  patrón de cola por App Group que ya usan los intents para todo lo demás, con la app emitiendo al
  materializar. Estimar antes de comprometerse.
- **O escribir un test de regresión que sostenga el criterio** y quitar de QA la línea de TelemetryDeck.
  Ya existe `YalaTests/StoreKitManagerAppGroupTests.swift`, del fix de julio, con un guard anti-drift de
  los identificadores de App Group. Si ese test cubre lo que el criterio pedía vigilar, el criterio se
  cambia por él y se cierra el punto 3 del ticket de Siri.

Lo que no es aceptable es dejar el criterio como está: pide mirar una métrica inexistente en un panel
retirado, y quien lo lea creerá que hay red.

## De dónde sale este ticket

Rescata un residual de **`tickets/discarded/rescue-discarded-groups-pull.md`**, que se archiva en este
mismo commit. Aquel ticket diseñó el rescate de gastos que el pull de Grupos descartaba y su guion de
QA se apoyaba en `groupsCkPullSkippedBackendGroup` con un `reason:` que distinguiera el eco stale
legítimo del dato realmente perdido. El rescate se descarta; **la observación rota que deja detrás no
se descarta con él**, y por eso vive aquí.

## Cómo re-medir esto (cuesta un minuto)

```bash
# canarios sin emisor
awk '/^enum MetricsCanary: String \{/,/^\}/' Yala/Services/Metrics/MetricsService.swift \
  | grep -oE '^    case [a-zA-Z]+' | awk '{print $2}' | while read c; do
    n=$(grep -rn "\.$c\b" --include="*.swift" . \
        | grep -v "Services/Metrics/MetricsService.swift:" \
        | grep -vE ':[0-9]+: *(//|///|\*)' | wc -l)
    [ "$n" -eq 0 ] && echo "HUERFANO $c"
  done

# breadcrumbs sin llamador (repetir por fichero de *Breadcrumb.swift)
F=Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift; B=$(basename $F .swift)
grep -oE 'static func [a-zA-Z0-9_]+' $F | awk '{print $3}' | while read fn; do
  [ "$(grep -rn "$B\.$fn(" --include='*.swift' . | wc -l)" -eq 0 ] && echo "HUERFANO $fn"
done
```

Dos trampas que este barrido tiene y que el script de arriba ya esquiva, pero un `grep` a ojo no:
un canario puede tener tres ocurrencias y estar muerto si las tres viven dentro de `MetricsService.swift`
(caso `invitePendingExpired`), y un helper privado sale como falso huérfano porque se llama sin prefijo
de tipo (caso `PushBreadcrumb.label`).

**No copies las coordenadas de este ticket sin re-medirlas.** El índice archivado de julio
(`docs/modo-nube/_archive/fase3-medicion/fase3-canarios-indice.md`) llegó a conclusiones casi idénticas
a las de aquí, y **ninguna de sus coordenadas sirve ya**: daba los canarios en `:43`-`:50` (hoy `:70`-`:77`)
y los breadcrumbs en `:136`/`:151`/`:160`/`:169`/`:201`/`:210` (hoy `:160`/`:175`/`:184`/`:193`/`:233`/`:242`).
`GroupsSyncBreadcrumb.swift` pasó de las 213 líneas y 25 funciones que ese informe midió a **275 líneas y
31 funciones**. El informe no se equivocó: midió bien su HEAD y lo dice en su propia cabecera. El árbol
se movió debajo.

## Qué NO cubre este ticket

- No se ha corrido build, tests ni QA. Todo lo de arriba es lectura del árbol.
- No se han revisado los eventos que emite el gateway (`gateway/`) — comprobé solo que ninguno de los
  once nombres huérfanos aparece allí.
- No se ha auditado el lado del dashboard de Analytics Engine: **infiero** que un slug sin emisor no
  produce filas, pero no he mirado si alguna query guardada los consulta y devuelve un panel vacío que
  alguien esté leyendo como verde.
