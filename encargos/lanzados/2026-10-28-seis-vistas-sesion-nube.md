# Que seis vistas que leen la sesión de la nube se repinten cuando esa sesión cambia

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `seis-vistas-sesion-nube` · Sesión cola **S17** · al cerrar → **S18**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/seis-vistas-sesion-nube-repaint-n533.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Un `@State` + `onReceive` por vista (molde nve0) o un contador observable común?** → contador `@Observable` (`CloudSessionRevision`), subido por `CloudAuthService` en el mismo sitio donde emite `sessionDidChangeNotification`, y leído junto a cada lectura de `hasSession` que pinta.
Por qué: dos de las lecturas no están en el `body` de una vista con estado propio («Tu cuenta de Yala», empujada, y `CloudAttestNotice.isShowing`, compartida por Panel y Almacenamiento); el contador ata el `body` que lo evalúe, sea cual sea. Es la misma señal que el aviso, no otra fuente. Alternativa descartada: `@State` por vista, que obliga a tocar PanelView y StorageSettingsView y acordarse de cada contenedor.

**D2 · ¿Se toca la pestaña de Grupos (nve0)?** → No. Sigue con su `GroupsIdentityRevisionObservers`. Por qué: el brief lo prohíbe y funciona.

**D3 · ¿Cómo se mide en el simulador si el seam solo se arma desde Grupos?** → El seam `-uitest-fake-cloud-session-after` se arma también al aparecer Ajustes (solo DEBUG, idempotente) y un XCUITest nuevo mide «Tu cuenta de Yala» con Ajustes abierto: rojo sin el arreglo (el «antes»), verde con él. Por qué: es la única de las seis donde la sesión puede cambiar con la vista delante y el seam la alcanza.

**D4 · Vistas donde el seam no llega (banner del attest exige `storageMode == .cloud`; aviso del Apple ID y educativo de Grupos son modales del arranque/Grupos; «Tu cuenta» solo existe con sesión).** → Se leen con el contador igual (una línea, sin coste), y el PR dice que esas son inferidas, no medidas.

**D5 · `WelcomeGroupsGateView`.** → No se toca: lee la celda solo en funciones (al evaluar y al confirmar), nunca en el `body`, y la confirmación la vuelve a leer. Consta en el PR y en el ticket.

**D6 · El hueco del SDK (sesión borrada tras refresco terminal sin aviso).** → Ticket aparte en `tickets/backlog/`, no en esta PR. Por qué: necesita observar el almacenamiento del SDK (`authStateChanges`), otra superficie y otro riesgo.
