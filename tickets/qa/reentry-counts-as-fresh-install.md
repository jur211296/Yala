---
id: reentry-counts-as-fresh-install
status: qa
created: 2026-08-12
updated: 2026-09-05
source: YalaWiki/Bugs/reentrada-la-vuelta-cuenta-como-instalacion-nueva.md
---


# Volver a Yala se parece demasiado a instalarla por primera vez

## El síntoma, en lenguaje de usuario

Cambio de móvil (o reinstalo). Entro con mi cuenta, la app me pide reiniciar, reinicio… y **Yala está
vacía**. Nada me dice que mis datos están bajando. Encima me recibe el **checklist de bienvenida como si
fuera nueva** y una **oferta de prueba** — llevo meses (o años) usando esto.

Y si algo va mal durante ese proceso, la barra dice «Conectando con tu cuenta…» tanto si me quedé sin red
como si mi cuenta está suspendida.

## Lo medido

### 1 · La app se ve vacía y el banner que lo explicaría excluye a quien vuelve

El banner **«Descargando tus datos…»** existe, y su docblock nombra el problema textualmente: «el store
secundario nace VACÍO […] la invitada vería una app "en cero" sin explicación»
(`SecondaryHydrationBanner.swift:5-8`).

Su gate es `secondaryActive && !firstPullCompleted` (`:17-21`). Tras el relanzamiento del adopt, **el
store personal del dueño nace igual de vacío** y se puebla con el pull desde el cursor 0 — pero el primer
término del gate lo excluye. El otro banner de la app solo cubre `.failed`/`.stalled` del sync de iCloud
(`SyncStatusBanner.swift:27-45`) ⇒ **no hay ninguna superficie**.

La señal que haría falta (`hasCompletedFirstPull`) es genérica y **ya está disponible**
(`SyncQuiescenceCoordinator.swift:55`, `:106`).

### 2 · Encima, ese mismo arranque re-arma el checklist y la oferta de prueba

`completeOnboardingAsRestoreSkip()` (`ContentView.swift:1918-1924`) marca `hasCompletedOnboarding`, arma
`needsPostOnboardingTrial` si el usuario no es Pro, y llama a `SetupChecklistManager.markAsNewInstall()`
(`:151-153`). El post-check de returning user (`ContentView.swift:1288-1300`) presenta la oferta.

Los tres efectos aterrizan sobre alguien que está **recuperando** su cuenta, y coinciden en el tiempo con
la ventana en la que la app se ve vacía.

*Hueco: no se midió si `SetupChecklistManager.autoDetect` repara el checklist tras el primer pull. Si
repara, esta pieza baja a cosmética.*

### 3 · Dentro del adopt, un 403 y quedarse sin red son indistinguibles

`performClaim` devuelve `sessionExpired`/`accountUnavailable`/`transient` con `return false` **sin emitir
evento**, así que la máquina se aparca y el usuario ve la misma barra «Conectando con tu cuenta…» con
auto-resume y botón manual, **sea 403 o sea falta de red** (`MigrationRunner.swift:533-546`). La única
señal es el breadcrumb `migrationAccountUnavailable`.

Fuera del adopt hay una asimetría relacionada: `GET /account/exists` mapea 401 a `sessionExpired` y todo
lo demás —403 incluido— al `default` `transient`, y `route` colapsa los dos a `.failed(retryable: true)`
⇒ una cuenta suspendida ofrece «Reintentar» en la re-entrada, mientras el alta born-cloud, correctamente,
no lo ofrece.

> **Matiz medido en la refutación**: `/account/*` **no emite 403 hoy** — el cliente lo declara defensivo
> (`CloudAccountClient.swift:31`). Así que esto es una **divergencia estructural** entre dos puertas que
> tratan el mismo error de forma distinta, no un fallo que un usuario esté viendo. Se arregla cuando se
> arregle, no antes que lo demás.

### 4 · Con el kill-switch se cierran LAS DOS puertas, y el residual solo menciona una

El residual escrito en el código dice que «un usuario nube que REINSTALA bajo el kill no ve la card → no
re-entra hasta re-encendido». Medido: la fila **«Dónde viven tus datos»** de Ajustes —la segunda puerta,
la de la adopción por marcador— **también desaparece**: su gate es `remoteEnabled || isEngaged`
(`StorageRowGateLogic.swift:50-62`) y una reinstalación no puede ser engaged. Además el faro deja de
encaminar, porque `cloudEntryAvailable` se deriva de la card que se fue
(`WelcomeAccountChoiceLogic.swift:57-70`).

Para un born-cloud, la única card que queda («Restaurar desde iCloud») termina en **«No encontramos tus
datos»** con sus datos intactos en el backend.

### 5 · El relanzamiento cero llegó al alta y no a la re-entrada — y la razón escrita es falsa

En un móvil recién instalado los dos caminos montan el mismo store neutro. El alta born-cloud pregunta al
testigo de mount y termina en «¡Tu cuenta está lista!» arrancando el motor **en sesión**; el adopt no
pregunta nada y cae en la terminal «Ya casi está — reinicia Yala».

Medido además que **`startAdoptWithExistingSession` NO llama a `startRuntimeIfStable()`** (sus tres
call-sites son `resume`, `pollLeader` y `resumeIfNeeded`) ⇒ hoy **el relanzamiento es lo único que arranca
el motor**: la pantalla es honesta en el efecto, y su justificación interna es falsa. El comentario de
`CloudWelcomeSignInFlow.swift:101-102` («El relaunch ya se resolvió en otro proceso — terminal
equivalente») describe mal este caso: aquí ningún proceso resolvió nada.

**Es una oportunidad, no solo una errata**: si el motor arrancara en sesión como en el alta, la
re-entrada podría dejar de pagar su relanzamiento.

### 6 · Y un belt que se justifica con una premisa falsa

El paso 4 de `runAdoptFlow` acepta `markerCount == 0` con un breadcrumb porque «la ruta ya validó el
marcador al abrir la pantalla» (`MigrationWorkExecutor.swift:1164-1170`). Cierto para la puerta de
Ajustes; **falso para la puerta del Welcome**, que nunca mira ningún marcador. En un móvil recién
instalado el marcador es **imposible** (vive en el mirror de CloudKit y el proceso montó sin mirror) ⇒ el
breadcrumb «marker absent» es el caso **normal** de este recorrido, no una anomalía a investigar.

## Prioridad sugerida

1. **El banner de hidratación** — cambiar el gate a la señal genérica. Es barato y quita el peor momento
   del recorrido.
2. **El checklist / oferta de prueba** en la vuelta — medir `autoDetect` primero.
3. **Evento explícito en `performClaim`** para separar cuenta-no-disponible de red.
4. Lo demás (kill-switch, docblocks) con el siguiente cambio que toque esos ficheros.

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]]
- [[_hallazgos-atlas-eje-persona-2026-08-12]] — el índice de esta tanda

## Implementación · pieza 1 de 4 (2026-08-12, `d10adddd`)

La que el propio ticket prioriza: **el banner de hidratación**. Coordenadas re-medidas y exactas
(`SecondaryHydrationBanner.swift:5-8` el docblock, `:17-21` el gate,
`SyncQuiescenceCoordinator.swift:55` la señal genérica).

El gate pasa de `secondaryActive && !firstPullCompleted` a leer el **mundo** en vez del camino:

```swift
guard !firstPullCompleted else { return false }
if secondaryActive { return true }          // su store SIEMPRE nace vacío
return cloudEngineActive && storeLooksEmpty  // el dueño que vuelve
```

**Por qué no basta con quitar el primer término** (que es lo que el ticket sugiere con «el gate solo
necesita cambiar de señal»): `hasCompletedFirstPull` es de **sesión de proceso**, así que a solas
pondría el banner en CADA arranque de un usuario de nube que ya tiene sus datos delante. Los dos
términos nuevos son exactamente los dos falsos positivos que hay que evitar: ya-tengo-mis-datos y
no-hay-motor-que-esté-descargando-nada.

`storeLooksEmpty` viaja desde el shell (`!hasExistingData`) y **no se re-calcula en el banner**: es el
MISMO detector que decide el alert del Welcome, y dos detectores distintos de «hay datos» es como
divergen. Coste: un parámetro en el init de `MainTabView`, con default `false`.

Pin: `SecondaryHydrationLogicTests` (3, reescrito). **Mutación a exit 65**: devolver el gate viejo
deja `returningOwnerIsCovered` en rojo. Gate: build ×2, 9 unit en 3 suites, índice OK.

## Implementación · piezas 2 y 3 (2026-09-05)

### El hueco de la pieza 2, MEDIDO: `autoDetect` NO repara el checklist

`SetupChecklistManager.autoDetect(transactionCount:budgetCount:scheduledCount:)` completa **3 de los 7**
pasos (`firstExpense`, `firstBudget`, `scheduledPayment` — los únicos que dejan rastro en SwiftData). Los
otros cuatro son gestos sin dato que los revele. Y el **primero de la lista** por orden de declaración
(= orden de `allCases` = orden de UI) es `exploreSettings`, que no es de los auto-detectables: con el
bloqueo secuencial resulta ser el único paso desbloqueado ⇒ quien vuelve ve «Configura tu Yala · 3/7 ·
Explora los ajustes» sobre una app que lleva usando años. **La pieza NO baja a cosmética.**

### 2 · el arreglo: la re-entrada deja de armar los dos efectos del alta

`completeOnboardingAsRestoreSkip()` tenía tres efectos y **sus tres call-sites son re-entradas**:
`RestoreRouter.decide == .directToApp`, `== .groupsOnly` (los dos, restaurar desde iCloud) y
`onAdoptStarted` (SIWA → exists → adopt). Ninguno es una instalación nueva — el alta real llama a
`markAsNewInstall()` por su cuenta, en el `onComplete` del onboarding de pasos.

La regla vive ahora en `Yala/App/Logic/EntryOnboardingEffects.swift` (`AppEntryKind.freshInstall` /
`.reentry`) y la consumen **los dos** caminos a través de `applyEntryOnboardingEffects(_:)`. Que la lea
también el alta no es adorno: con un solo consumidor el enum sería decorativo y la mutación no se vería.

Las claves `setup.*` **no viajan** en el espejo de prefs ni en ningún mirror (medido), así que en un
móvil recién instalado `setup.isNewInstall` no existe ⇒ `isExistingUser == true` ⇒ la card no se muestra.
Es el mismo trato que ya recibía quien actualizó desde una versión anterior al checklist.

**La oferta Pro no se pierde**: quien vuelve y no es Pro la sigue recibiendo por el canal de los usuarios
existentes (`ProUpsellService.shouldShowPeriodicBanner`, cooldown de 5 días y tope de 4/mes). Lo que se
retira es la oferta *de alta*, que prometía un estreno a quien lleva meses dentro.

### 3 · el 403 deja de disfrazarse de problema de red

No por un evento de la máquina: el docblock del propio runner prohíbe alimentar `fatalError` desde un
no-success del claim (haría un rollback espurio) y aquí no hay nada que revertir, porque sin claim
otorgado no se creó nada. Se sigue el molde de `cutoverBlocker` — un hecho que solo elige copy:

1. `MigrationRunner.lastClaimBlocker` (en memoria, fuera del journal) registra la causa en los **dos**
   consumidores de `performClaim` (`driveClaim` y `pollLeaderInternal`); un claim otorgado la limpia.
   `transient` NO marca: la red sí se reintenta y no debe apagar la barra de progreso.
2. `CloudMigrationController.claimBlocker` lo expone, leído en `refresh()` vía `_runner?` y **nunca** por
   la property lazy `runner` — ésa construiría executor y clients desde el `init`.
3. `CloudWelcomeSignInFlow.phase(for:claimBlocker:)` lo antepone al progreso, salvo sobre los terminales
   de éxito (un bloqueo de un intento viejo no debe tapar un adopt que ya terminó).
4. Fase de pantalla propia `.accountBlocked`, con icono de cuenta y copy que descarta la conexión de
   forma explícita. `.error(retryable: false)` no servía: comparte icono de wifi y un cuerpo que empieza
   por «Revisa tu conexión», así que mandaba a mirar el router ante una cuenta bloqueada.

**Todas las instancias del patrón**: el alta born-cloud tenía el mismo disfraz (`BornCloudSignUpFlow`
mapeaba el 403 a `.error(retryable: false)`) y pasa a la misma pantalla. Las dos puertas cuentan por fin
lo mismo. Copy nuevo en los 16 locales (`welcome.cloud.accountBlockedTitle` / `Body`, con el correo de
soporte por parámetro) e identifier `welcome_cloud_account_blocked`.

`canGoBack` incluye `.accountBlocked`: el claim fue rechazado, no hay nada comprometido, y una terminal
sin retry **ni** salida sería un callejón.

### Verificación

Build ×2 verde. 102 unit en 7 suites de las áreas tocadas. **Mutantes a exit 65**: devolver `true`
incondicional en las dos funciones de `EntryOnboardingEffects` deja 4 rojos; ignorar el `claimBlocker` en
`phase(for:)` deja 3. Pines nuevos: `EntryOnboardingEffectsTests` (6),
`CloudWelcomeSignInFlowClaimBlockerTests` (6), `MigrationRunnerTests` (2),
`SetupChecklistManagerTests` (2), y `BornCloudSignUpFlowTableTests` actualizado.

**Lo que NO se ha visto correr:** llegar a `.accountBlocked` exige un 403 real del backend y un sign-in
real con SIWA — el simulador no firma. La cobertura es unit + el identifier puesto para que el device-QA
pueda anclarse sin recompilar (mismo criterio que `welcome_cloud_blocked_foreign_data`).

## Piezas que siguen abiertas

- **4 · kill-switch y docblocks**, más el §5 (relanzamiento cero en la re-entrada, que es OPORTUNIDAD de
  producto y no un defecto) y el §6 (el belt que se justifica con una premisa falsa). Ninguna se tocó:
  el §4 pide una decisión de producto sobre el kill-switch y los otros dos son diseño y comentario.
  Salen a su propio ticket: `tickets/backlog/reentry-killswitch-closes-both-doors.md`.

migrated from YalaWiki Bugs/reentrada-la-vuelta-cuenta-como-instalacion-nueva.md @ 1934e8ad
