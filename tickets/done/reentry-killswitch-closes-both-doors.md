---
id: reentry-killswitch-closes-both-doors
status: done
created: 2026-09-05
updated: 2026-09-23
source: tickets/qa/reentry-counts-as-fresh-install.md (§4, §5 y §6)
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - la fase con kill exige bajar el percent del gateway; la fase sin kill se ve en reentry-counts-as-fresh-install
---


# Con el kill-switch, quien vuelve se queda sin las DOS puertas

Sale de `reentry-counts-as-fresh-install`, cuyas piezas 1-3 quedaron cerradas el 2026-09-05. Lo que
sigue aquí es lo que **no** se tocó: una pieza que necesita decisión de producto y dos que son diseño y
comentario, no fix. Se separan para que el ticket padre pueda irse a QA sin arrastrarlas.

**Las coordenadas de abajo vienen del ticket padre y NO se re-midieron en esta sesión.** Greppea antes de
abrir una línea citada.

## 1 · El residual escrito solo menciona una de las dos puertas

El comentario en el código dice que «un usuario nube que REINSTALA bajo el kill no ve la card → no
re-entra hasta re-encendido». Lo que el padre midió es que la fila **«Dónde viven tus datos»** de
Ajustes —la segunda puerta, la de la adopción por marcador— **también desaparece**: su gate es
`remoteEnabled || isEngaged` (`StorageRowGateLogic`) y una reinstalación no puede ser engaged. El faro
además deja de encaminar, porque `cloudEntryAvailable` se deriva de la card que se fue
(`WelcomeAccountChoiceLogic`).

Para un born-cloud, la única card que queda («Restaurar desde iCloud») termina en **«No encontramos tus
datos»** con sus datos intactos en el backend.

**Por qué no entró:** tocar el gate del kill-switch es una decisión de producto de Jürgen —el encargo del
5-sep lo excluía explícitamente— y lo barato mientras tanto es que el residual del código deje de
describir mal lo que hace. Lo mínimo aquí es corregir ese comentario; lo completo es decidir si la
segunda puerta debe seguir viva bajo el kill.

## 2 · El relanzamiento cero llegó al alta y no a la re-entrada

En un móvil recién instalado los dos caminos montan el mismo store neutro. El alta born-cloud pregunta
al testigo de mount y termina en «¡Tu cuenta está lista!» arrancando el motor **en sesión**; el adopt no
pregunta nada y cae en la terminal «Ya casi está — reinicia Yala».

Medido en el padre: `startAdoptWithExistingSession` **no** llama a `startRuntimeIfStable()`, así que hoy
el relanzamiento es lo único que arranca el motor — la pantalla es honesta en el efecto, pero el
comentario de `CloudWelcomeSignInFlow` («el relaunch ya se resolvió en otro proceso — terminal
equivalente») describe mal este caso: aquí ningún proceso resolvió nada.

**Es una oportunidad de producto, no un defecto**, y por eso no se implementó: si el motor arrancara en
sesión como en el alta, la re-entrada podría dejar de pagar su relanzamiento. Necesita decisión antes que
código.

## 3 · Un belt que se justifica con una premisa falsa

El paso 4 de `runAdoptFlow` acepta `markerCount == 0` con un breadcrumb porque «la ruta ya validó el
marcador al abrir la pantalla» (`MigrationWorkExecutor`). Cierto para la puerta de Ajustes; **falso para
la puerta del Welcome**, que nunca mira ningún marcador. En un móvil recién instalado el marcador es
*imposible* (vive en el mirror de CloudKit y el proceso montó sin mirror) ⇒ el breadcrumb «marker absent»
es el caso **normal** de este recorrido, no una anomalía a investigar.

Es un docblock, y la prioridad del padre decía «con el siguiente cambio que toque esos ficheros». Las
piezas 2 y 3 no tocaron `MigrationWorkExecutor.swift`, así que sigue esperando a quien lo haga.

## Decisión Jürgen (2026-09-06)

Las piezas 1 y 2 pedían decisión; la 3 es un docblock y no se le preguntó.

**Pieza 1 — bajo el kill, las DOS puertas cerradas es lo deseado, y se arregla el mensaje.** Elegida
entre tres: (a) las dos cerradas + corregir comentario + corregir el mensaje del Welcome, (b) las dos
cerradas y solo el comentario, (c) mantener viva la puerta de Ajustes bajo el kill. Eligió (a). Motivo,
tal como se le puso delante y ratificó: el kill significa **nube en pausa para todos, también para
volver**; lo que no es aceptable es que un nacido-en-nube con sus datos intactos lea «No encontramos tus
datos». Descartó (c): tocar el gate del kill (`StorageRowGateLogic`) es tocar el freno de emergencia.

Lo que implica: el residual del código pasa a decir que bajo el kill se cierran **las dos** puertas
(card del Welcome y fila «Dónde viven tus datos»), y el camino «Restaurar desde iCloud» bajo el kill
termina en un mensaje que dice que la nube está en pausa, no que los datos no existen. Copy nuevo, 16
`.lproj`.

**Pieza 2 — el motor arranca en sesión también en la re-entrada.** Elegida entre dos: arrancar el
motor en sesión como hace el alta, o dejar el relanzamiento y corregir el comentario. Eligió la primera.
Motivo, tal como se le puso delante y ratificó: es la versión robusta y la coherente con el alta —dos
caminos que montan el mismo store neutro no deberían terminar en pantallas distintas—. Lo que implica:
`startAdoptWithExistingSession` llama a `startRuntimeIfStable()` (o su equivalente en el flujo) y la
re-entrada termina en «¡Tu cuenta está lista!» en vez de «Ya casi está — reinicia Yala»; el comentario
de `CloudWelcomeSignInFlow` que hablaba de «terminal equivalente» se reescribe.

**Pieza 3** sigue como estaba: docblock de `MigrationWorkExecutor`, con el siguiente cambio que toque el
fichero.

## Criterio de hecho (AC)

- [x] Con el kill encendido y una instalación limpia, ni la card del Welcome ni la fila de Ajustes
      ofrecen la nube, y el comentario del código lo dice de las **dos** puertas.
      **Medido, no heredado:** el «ya pasa hoy» del ticket es cierto y ésta es su prueba —
      `visibleExistingOptions` con `remoteCloudEnabled: false` devuelve solo `.restoreICloud`
      (fijado por `existingOptions_remoteKillSwitch_onlyRestore`), y en la fila
      `remoteEnabled || isEngaged` es falso por los dos lados porque `isEngaged` se computa con
      `StorageModePersistence.read()` + el `uiState` del journal (`ProfileView.swift:977-979`), y
      los dos viven en UserDefaults / store local: **una reinstalación los borra, así que no
      puede estar engaged**. El residual completo pasa a `WelcomeAccountChoiceLogic`
      (`visibleExistingOptions`) y `StorageRowGateLogic` cruza hacia él.
- [x] Con el kill encendido, un nacido-en-nube que pasa por «Restaurar desde iCloud» lee que la nube
      está en pausa, **no** «No encontramos tus datos». Copy propio, 16 `.lproj`.
      Estado `.cloudPaused` en `WelcomeRestoreView`, decidido por `WelcomeRestoreEmptyOutcome`
      (faro del iCloud-KV + flag remoto; se llamaba `WelcomeRestorePauseLogic.isCloudPaused` hasta el
      2026-09-17, cuando `reinstall-without-network-has-no-cloud-door` le añadió un tercer desenlace
      y lo convirtió en una sola decisión). Claves `welcome.restore.cloudPaused{Title,Body}`,
      traducidas en los 16 locales — `LocalizationParityTests` en verde (11 casos).
- [x] La re-entrada por la puerta del Welcome en un móvil recién instalado arranca el motor en sesión
      y termina en la misma pantalla de «lista» que el alta; **sin** «reinicia Yala».
      `startAdoptWithExistingSession` llama a `startRuntimeIfStable()`, y
      `phase(for: .cloudActive)` pasa de `.relaunch` a `.reentryReady` — la misma PANTALLA del
      alta (mismo copy, mismo botón) pero con salida propia, por lo que dice el hallazgo 1 de
      abajo.
- [x] La re-entrada por la puerta de Ajustes se comporta igual (mismo `runAdoptFlow`); arrancar el
      motor en sesión **no** rompe el caso con marcador presente.
      **Comprobado, y el guard que lo sostiene ya existía:** con marcador el proceso montó CON el
      mirror de CloudKit, así que `CloudSyncRuntime.canRunDomain()` devuelve `false` por
      `personalMountMismatch` (`CloudSyncRuntime.swift:260-268`, consultado desde el
      `guard` de `start()`) ⇒ la llamada nueva es **no-op** ahí, `derive` sigue dando
      `.needsRelaunch(.toCloud)` y la terminal correcta sigue siendo el relanzamiento.
      Ajustes entra por `startMigration`, que **no** se tocó: su relanzamiento es obligatorio por
      construcción del mount, no una omisión.
- [ ] Device-QA: móvil limpio (borrar app) × {kill apagado, kill encendido} × {alta, re-entrada}.
      **Es lo único que queda**, y el kill se conmuta desde el backend. Guion abajo.
- [x] Coordenadas re-medidas: las del padre eran correctas en los símbolos, y todas existen en este
      árbol. Lo que NO decían: el mapeo `.cloudActive → .relaunch` es la otra mitad de la pieza 2
      (sin él, arrancar el motor habría dejado la pantalla pidiendo un relanzamiento igual).
- [x] Review adversarial hecha antes del gate (tres lentes: sync/carrera, producto, regresión).

## Lo que la review encontró, y los cuatro eran míos

Tres lentes independientes (sync/carrera, producto, regresión). Ninguno de los cuatro defectos
existía antes del chip: **los introduje yo**, y ninguno lo habrían cazado los 6291 tests.

**1 · La CTA mandaba al onboarding de 8 pasos a quien re-entra. El grave.** Reusé la terminal del
alta (`.bornCloudReady`) razonando que «no son dos hechos distintos, es el mismo por dos caminos».
Era falso, y lo que los separa no es el camino sino la PRECONDICIÓN: `onAdoptStarted` marca
`hasCompletedOnboarding` **antes** de conducir la máquina, y su comentario dice exactamente para
qué — «cierra el hazard kill-mid-adopt → el seed del onboarding jamás corre sobre una cuenta
existente». Mi CTA deshacía esa defensa: `createOnboardingAccount` inserta una cuenta **sin
comprobar existencia** y `seedCategoriesIfNeeded` siembra si el pull no aterrizó — y con el motor ya
arrancado en sesión, las dos cosas **suben al backend** y se abanican a los demás devices. Además,
el comentario con el que justifiqué el cambio era **falso**: afirmaba que `presentNextOnboardingScreen`
manda al onboarding, cuando `checkInitialSyncState` sale antes por `runReturningUserPostChecks` con el
flag ya puesto. Fase propia `.reentryReady`, salida a la app.

**2 · Mi «Reintentar» no podía cambiar su desenlace.** `resolveEmptyState` leía
`CloudRemoteFlags.cloudModeEnabled` sin refrescar, y `refreshIfDue` **sin `force: true` es un no-op
mientras el último fetch tenga menos de 6 h** — el caso normal, porque el boot acaba de refrescar.
Como el kill se conmuta desde el backend, el usuario podía pulsarlo indefinidamente leyendo siempre
el snapshot del arranque. El repo ya lo tiene escrito en **cuatro** sitios
(`WelcomeGroupsGateView`, `GroupsContainerView`, `GroupsOrganizerGateLogic`,
`GroupCreateRoutingLogic`); el mío era el quinto y el único sin forzar. Y la forma del defecto es la
del bug que este ticket arregla: **una pantalla que promete algo que no cumple**.

**3 · El motor podía arrancar sobre una migración a medias.** `startRuntimeIfStable` pedía la tupla
`(fase, pendientes)` y **tiraba la segunda mitad**. `notStarted` es fase ESTABLE y es también la que
el adopt journalea ANTES de ejecutar su efecto, así que un `.adoptBackendAccount` que falla de forma
retomable deja `(notStarted, pendiente)` — y falla **en silencio**, porque `runGuarded` traga
`Stop.effectFailed`. Era el único consumidor de la fase que no aplicaba la regla que
`MigrationBootDecision.decide` ya tiene escrita («un efecto pendiente FUERZA `.resume` aunque la
fase sea estable»), y no se notaba porque sus tres call-sites previos llamaban justo tras drenar. El
cuarto —el mío— no tiene esa garantía.

**4 · En sesión secundaria el aviso hablaba de la cuenta del dueño.** El faro vive en el iCloud-KV
del Apple ID del teléfono y `OwnerKeyValueStore` **no bloquea las lecturas a propósito**. Una
invitada monta con `cloudKitDatabase: .none` ⇒ su búsqueda sale vacía SIEMPRE ⇒ habría leído «tus
datos están a salvo en tu cuenta» sobre una cuenta ajena, enterándose de paso de que el dueño tiene
una. `.notFound` era inexacto para ella; esto habría sido peor, porque **afirma**.

**Y dos daños colaterales de documentación**, que en este repo cuestan una vuelta de diagnóstico: el
poll del adopt se quedaba vivo a 1 Hz bajo una pantalla terminal (antes paraba porque el caso
llegaba como `.relaunch`), y el docblock de `WelcomeAdoptAutoResume` afirmaba una lista de
terminales que había dejado de ser cierta.
Fijado por `pauseIsDecidedOnAFreshFlag`.

## Device-QA — el guion, y por qué no se puede hacer desde aquí

**Nada de esto es ejercitable en simulador**, y conviene tenerlo escrito para que nadie lo dé por
verificado: SIWA no corre en sim; el kill se conmuta desde el **backend** (percent del gateway), no
con un flag local; y bajo `-uitest` los getters de remote-config cortocircuitan a su default
(`absentDefault`, que en DEV es `true`) ⇒ **el desenlace es siempre `.notFound` en XCUITest**. Desde
el 2026-09-17 lo sostiene otro término además del flag: `CloudRemoteFlags.cloudConfigKnown` corta en el
host de test igual que `decide()` (`RemoteFlagDecisionLogic.isConfigKnown`, `isTestHost`), así que el
estado nuevo `.cloudUnverified` tampoco es alcanzable ahí. El
`accessibilityIdentifier("welcome_restore_cloud_paused")` existe para el día que se pueda, no promete
cobertura hoy.

Matriz: móvil limpio (borrar la app entre casos) × {kill apagado, kill encendido} × {alta, re-entrada}.

1. **Kill ENCENDIDO** (`CLOUD_MODE_ROLLOUT_PERCENT = "0"` en el gateway; es el estado de prod hoy).
   1. Borrar la app. Abrir → «Ya tengo cuenta». Debe hacer **bypass a «Restaurar desde iCloud»**
      (card de sign-in ausente = la primera puerta cerrada).
   2. En Ajustes → Perfil, la fila **«Dónde viven tus datos» no aparece** (segunda puerta).
   3. Con un Apple ID que **tenga cuenta nube** (faro puesto), dejar terminar la búsqueda:
      debe leerse **«La nube de Yala está en pausa»**, NO «No encontramos tus datos».
   4. Pulsar **«Reintentar búsqueda»** y comprobar en Console.app que sale un fetch de config
      (`refreshIfDue(force: true)`): el botón tiene que poder cambiar el desenlace.
   5. Con un Apple ID **sin** cuenta nube, la misma pantalla debe seguir diciendo «No encontramos tus
      datos» — es el control que prueba que el faro discrimina y no es un mensaje fijo.
   6. **Sesión secundaria (visita) bajo el kill**: la invitada NO debe ver el aviso de pausa (lee el
      faro del dueño). Breadcrumb `CLOUD-PAUSED` ausente en su recorrido.
2. **Kill APAGADO** (subir el percent en el gateway):
   1. **Re-entrada**, móvil limpio: «Ya tengo cuenta» → sign-in → adopt. Debe terminar en
      **«¡Tu cuenta está lista!»** y el botón debe llevar a **la app**, NO al onboarding de 8 pasos.
      *Es la comprobación que más importa* — y las dos terminales se ven IGUAL, así que lo que las
      distingue es el identificador: `welcome_reentry_ready` (re-entrada, sale a la app) frente a
      `welcome_born_cloud_ready` (alta, sale al onboarding). Si aterriza en el onboarding con el id
      de re-entrada, el mapeo de `.cloudActive` se rompió.
   2. Confirmar que **no** aparece «Ya casi está — reinicia Yala», y que los datos bajan solos
      (el motor arrancó en sesión) sin cerrar la app.
   3. Tras completar, comprobar que **no hay cuenta duplicada** ni categorías sembradas de más.
   4. **Alta born-cloud** (control): debe seguir terminando en la misma pantalla pero su botón sí
      lleva al onboarding — son dos salidas distintas y el device es donde se ve.
   5. **Re-entrada CON marcador** (device que ya tenía la app en modo nube): debe seguir pidiendo el
      relanzamiento. Es el caso que el gate del mount protege y el único que aún debe verlo.

## Pieza 3 — sigue esperando, a propósito

El docblock de `MigrationWorkExecutor` (el belt del `markerCount == 0`) **no** se tocó: la decisión
del 6-sep lo condiciona a que el chip toque ese fichero, y no lo tocó. Se leyó para responder al
AC de la puerta de Ajustes, y leer no es tocar.

## Relacionados

- [[reentry-counts-as-fresh-install]] — el padre, en `qa/` desde el 2026-09-05


---

## Nota del 2026-09-11 — la decisión de la pieza 1 sigue vigente, y la fila ya no está cerrada

**No es una vuelta atrás.** La decisión del 6-sep («las dos puertas de la NUBE cerradas bajo el kill») se
cumple entera: la entrada personal a la nube sigue cerrada, y desde hoy lo está con un candado propio
(`StorageRowGateLogic.offersCloudMigrationEntry`) en vez de por el efecto lateral de esconder la fila.

Lo que cambió es la premisa. El paso 10 (9-sep) metió detrás de esa misma fila la gestión de la **cuenta
de grupos** —que va por `groupsBackendRolloutPercent`, otro flag— y con ella la única superficie desde la
que se suelta. El kill de la nube apagaba un control de Grupos. Encargo de Jürgen del 11-sep:
`cloud-killswitch-hides-the-only-door-to-detach-groups`, opción (1).

⇒ Al leer la decisión de más arriba, la frase «descartó (c): tocar el gate del kill es tocar el freno de
emergencia» hay que leerla con su alcance: valía para la puerta de la NUBE, que es lo que estaba sobre la
mesa ese día. La fila hoy se abre por el eje de Grupos y por nada más.

## Correcciones al guion · 2026-09-16 (barrido de QA, medidas en este árbol)

- **Fase 1, cabecera (:186)** — «`CLOUD_MODE_ROLLOUT_PERCENT = "0"`; es el estado de prod hoy» **ya no
  vale**: según `CloudRemoteConfig.swift:18-20`, producción sirve los percents en 100 (`CLOUD_MODE` desde
  el 2026-07-30). Para probar el kill encendido hay que **bajarlo a propósito** en el
  gateway y volver a subirlo al terminar.
- **Paso 1.2 (:189)** — sigue siendo cierto en un móvil limpio. Matiz desde el 2026-09-11: con una
  cuenta de Grupos asociada la fila **sí** sale, con «Desasociar» y sin «Migrar a la nube» (visto en
  simulador hoy, `cloud-killswitch-hides-the-only-door-to-detach-groups`).
- **Paso 1.6 (:196-197)** — la sesión de visita se retiró (ADR del 2026-09-09, «Sesiones — dos ejes»).
  **Sáltalo.**

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). La fase con la nube en pausa exige bajar el porcentaje del gateway. La fase normal (volver a tu cuenta acaba en «¡Tu cuenta está lista!») se ve en `reentry-counts-as-fresh-install`, que sigue en `qa`. Lo cubre `WelcomeAccountChoiceLogicTests`.
