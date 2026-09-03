---
id: invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo
status: backlog
priority: high
area: grupos
created: 2026-09-02
updated: 2026-09-02
---

# El refresco forzado de la invitación no hace nada si ya hay otro en vuelo

## Qué le pasa al usuario

Alguien acaba de instalar Yala. Abre el enlace de invitación que le mandaron y, en vez de entrar
al grupo, le sale una alerta: **«Hubo un problema con el grupo — No pudimos abrir esta invitación
ahora. Guardamos tu solicitud: vuelve a intentarlo en un momento.»**

El mensaje es **falso en su causa**: Grupos puede estar perfectamente encendido para él. Lo único
que pasó es que la app no llegó a preguntarlo. Se lo dice al usuario en su primer minuto con el
producto y en el peor momento posible: en el estreno, viniendo de un enlace que alguien le mandó.

No es aleatorio ni raro. Es **el perfil exacto del recién instalado**: teléfono sin nada guardado
todavía, arranque en frío y enlace tapeado enseguida. Cuanto peor la red, más ancha la ventana.

La solicitud sí queda guardada antes de fallar, así que el daño es de primer contacto, no pérdida
de datos: reintentar suele funcionar. Que además la complete sola la reconciliación en un arranque
posterior lo afirma `tickets/qa/invite-backend-stale-config.md` (intent con TTL 7 días, cuatro
disparadores); **no lo medí en esta pasada** — lo que sí medí es que el intent se persiste antes
del refresco (`AppBootstrapper.swift:2007`) y otra vez en la rama que muestra la alerta (`:2018`).

## Por qué pasa

**El `force` no fuerza lo que promete.** Salta el min-interval, pero no salta un refresco que ya
está en curso — y en el arranque en frío siempre hay uno en curso.

Medido en `Yala/Services/CloudSync/CloudRemoteConfig.swift`, HEAD `553b91c9`:

```swift
253   func refreshIfDue(force: Bool = false, now: Date = .now) async {
254       guard CloudBackendConfig.isConfigured else { return }
255       guard !inFlight else { return }                                    // ← sale ANTES
256       let last = CloudRemoteConfigStore.readSnapshot(defaults)?.fetchedAt
257       guard force || RemoteFlagDecisionLogic.shouldRefresh(...) else { return }  // ← el force vive aquí
```

El propio doc-comment lo dice en `:250-252`: «Idempotente y coalescente (un fetch en vuelo hace
no-op del siguiente kick). `force` salta el **min-interval**». Nunca prometió saltar el en vuelo.
El problema es que los call-sites sí lo dan por hecho.

### La cadena completa, con coordenadas

1. **El arranque lanza su propio refresco.** `AppBootstrapper.swift:297-298`, paso 14.56:
   `if CloudBackendConfig.isConfigured && !uiTestActive { Task { await RemoteConfigClient.shared.refreshIfDue() } }`.
   Sin `force`, pero no le hace falta: `RemoteFlagDecisionLogic.shouldRefresh` devuelve `true`
   cuando nunca se fetcheó (`RemoteFlagDecisionLogic.swift:50`, `guard let lastFetchedAt else { return true }`),
   y el min-interval son 6 h (`:22`). En un teléfono recién instalado **ese refresco va a red sí o sí**.

2. **Con el snapshot ausente, el canal se lee apagado.** `CloudRemoteFlags.decide` sale por
   `guard let snapshot ... else { return absentDefault }` (`CloudRemoteConfig.swift:190`), y en
   producción `absentDefault` es `false` (`:120-126`, fail-closed). El compuesto
   `CloudSyncFlags.groupsBackendEnabled` (`CloudSyncFlags.swift:347`) queda en `false`.

3. **El enlace enruta a «refresca y reintenta».** `GroupInviteChannelRoutingLogic.route` con
   `isBackendLink: true`, `flagEnabled: false`, `didRefreshFlags: false` devuelve
   `.refreshFlagsThenRetry` (`GroupInviteChannelRoutingLogic.swift:70`).

4. **El refresco forzado es un no-op.** `AppBootstrapper.swift:1998` abre la rama; `:2010` llama
   `await RemoteConfigClient.shared.refreshIfDue(force: true)` — que si el refresco del arranque
   sigue en vuelo **retorna en `CloudRemoteConfig.swift:255` sin tocar la red ni escribir nada**.

5. **La re-lectura inmediata cae en la rama equivocada.** `AppBootstrapper.swift:2011` re-entra en
   `handleInviteLink(url, didRefreshFlags: true)`. El flag se vuelve a leer y sigue apagado, porque
   nadie escribió el snapshot; `route` (`:70`) devuelve ahora `.backendUnavailable`
   (`AppBootstrapper.swift:2014`) y se emite la alerta en `:2026`
   (`.showGroupSyncError` con `groups.invite.channelUnavailable`).

**Nada espera al que está en curso.** La ventana dura lo que dure la petición del arranque:
`refreshIfDue` construye su `URLRequest` sin fijar `timeoutInterval` (medido: solo pone
`httpMethod` y, con `force`, `cachePolicy`), así que rige el default de `URLSession` — **infiero**
60 s, que es el valor de plataforma, no algo medido en este repo.

### La copy que ve el usuario

- Título de la alerta: `groups.bridge.alertTitle` → «Hubo un problema con el grupo»
  (`Yala/Resources/es.lproj/Localizable.strings:3478`), montada en `ContentView.swift:2045-2055`
  sobre `activeGroupSyncError` (`:933`).
- Cuerpo: `groups.invite.channelUnavailable` → «No pudimos abrir esta invitación ahora. Guardamos
  tu solicitud: vuelve a intentarlo en un momento.» (`es.lproj/Localizable.strings:5397`; existe en
  los 16 locales).

## Contradice un criterio de aceptación de la QA en curso

`tickets/qa/invite-backend-stale-config.md` (status `qa`) deja tres casos abiertos bajo
**«REMAINS (C) — owner / TestFlight»**. Dos chocan de frente con esto:

- **(2)** «enlace backend con config vieja (snapshot < 6 h) → se une igual, **sin mensaje de
  error** (refresh forzado)».
- **(4)** «cold launch + enlace backend → se une tras el arranque» — que es literalmente la ventana
  descrita arriba.

Quien corra esa QA y vea la alerta **la va a clasificar como «el canal está caído»**, no como este
agujero, y no por descuido: la decisión técnica nº 4 de ese mismo ticket y la copy dicen que ese
mensaje significa exactamente eso. Y no hay forma de distinguirlos desde fuera —

- **misma alerta y misma clave** que el apagado real,
- **mismo canario y mismo `detail`**: `MetricsService.canary(.groupJoinIntentDeferred, detail: "backendChannelOff")`
  en `AppBootstrapper.swift:2020` y en `GroupBackendInviteEntryHandler.swift:308`. Ese comentario
  dice que la fusión en una sola serie es deliberada («una serie, no dos que hay que sumar en el
  dashboard»), y **para el kill-switch real está bien**; el efecto colateral es que este agujero
  tampoco se separa en telemetría.

⇒ mientras esto siga vivo, **el caso (4) no se puede dar por FAIL ni por PASS con la alerta como
única evidencia**. Hay que mirar el breadcrumb `remoteConfig fetched` / `fetchFailed` en Console
(`CloudRemoteConfig.swift:298-315`) para saber si el server llegó a contestar.

## Arreglo propuesto

### Opción A — que `force` salte también el en-vuelo

Un `guard force || !inFlight else { return }` en `:255`, o bajar ese guard por debajo de `:257`.

**No.** `inFlight` es un `Bool` con `defer` (`:238`, `:258-259`): con dos corridas simultáneas, la
primera que termina lo pone en `false` mientras la otra sigue, y la coalescencia de la que depende
todo lo demás deja de existir. Además las dos escriben el snapshot en éxito (`:284`), así que la
respuesta **más vieja puede aterrizar la última** y pisar a la más nueva. Y elimina justo el tope
que el propio call-site nombra como razón de que forzar desde una acción de usuario sea seguro
(`AppBootstrapper.swift:2005-2006`: «el spam queda acotado por el guard `inFlight` del cliente»).

### Opción B — esperar al que está en curso (recomendada)

Cambiar `inFlight: Bool` por el handle de la task, y que el caller haga `await` sobre ella y
**vuelva a evaluar** en vez de rendirse. El molde ya existe en este repo:
`GroupsSaveSyncTrigger.swift:39` (`private var inFlight: Task<Void, Never>?`) y `:103`
(`await inFlight?.value`).

**Por qué es la más segura:** un fetch solo está en vuelo *después* de pasar los dos guards
(`:255`, `:257`), así que **siempre es una llamada de red real**. Esperarlo le da al que forzó
exactamente lo que pedía —la respuesta más fresca del servidor— sin una segunda petición y sin
escrituras fuera de orden. La A añade tráfico y una carrera; la B no añade ninguno de los dos.

Dos cosas que el arreglo tiene que cubrir, o cambia un fallo por otro:

1. **Que el fetch esperado falle** (no-200 o error de red): el snapshot no avanza, y si el que
   forzó se conforma con eso, la invitación enseña la misma alerta equivocada cada vez que el
   refresco del arranque falle. Tras el `await`, si el snapshot no avanzó, el `force` debe lanzar
   su propio intento.
2. **La cancelación es cooperativa.** `WelcomeGroupsGateView.swift:158` ya documenta que
   `refreshIfDue` no la mira; esperar al de otro **alarga** esa ventana. Es suspensión, no bloqueo
   de UI, pero hay que decidirlo a propósito.

**Mismo agujero, otras puertas** (heredan el arreglo sin tocarlas): `WelcomeGroupsGateView.swift:155`,
`GroupsContainerView.swift:710` y `CloudSyncDebugView.swift:894` pasan `force: true` y confían en
lo mismo. La puerta del organizador es especialmente parecida: su `.task` de onboarding convive
con el `refreshIfDue()` sin `force` de `WelcomeFlowContainer.swift:204`.

## Lo que la suite no ve

Cinco source-scans afirman que la llamada lleva `force: true`, y **ninguno ejercita qué hace ese
`force`** — comprueban que el literal está en el fuente:

| Test | Línea |
|---|---|
| `YalaTests/GroupInviteChannelRoutingLogicTests.swift` | `:216`, `:289` |
| `YalaTests/GroupCreateRoutingLogicTests.swift` | `:129` |
| `YalaTests/Groups/GroupsOrganizerBranchTests.swift` | `:388` |
| `YalaTests/GroupsGateLogicTests.swift` | `:396` |

Los cinco están **verdes con este bug vivo**, y seguirían verdes si el arreglo se hiciera mal.
Falta un test de comportamiento sobre `RemoteConfigClient`, que es inyectable para eso: su `init`
(`CloudRemoteConfig.swift:240-248`) recibe `urlSession: SyncHTTPSession` y `defaults`. La forma:
una sesión que se quede suspendida, un `refreshIfDue()` sin `force` que la deje en vuelo, y un
`refreshIfDue(force: true)` que **no** debe volver antes de que el snapshot exista.

## Coordenadas re-medidas

Todas contra `2.1` @ `553b91c9`. Las tres pistas de partida sobrevivieron sin derivar:
`CloudRemoteConfig.swift:255` / `:257`, `AppBootstrapper.swift:298` y `AppBootstrapper.swift:2010-2011`
están donde decía la pista. Las demás coordenadas de este ticket son medición propia de hoy.
