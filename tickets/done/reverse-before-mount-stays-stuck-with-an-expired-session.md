---
id: reverse-before-mount-stays-stuck-with-an-expired-session
status: done
qa-status: not-replicable
implementation_date: 2026-09-17
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
updated: 2026-09-23
source: "Paso 0 de `reverse-claim-rejection-has-no-way-out-in-the-client` (D11), 2026-09-16: medido en el código al separar el rechazo del claim de la sesión caducada"
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - depende de borrar la sesion justo mientras avanza la barra; 161 casos y 13 mutantes
---

# Si la sesión de la nube caduca durante «Volver a iCloud», la barra se queda parada sin decir que hay que volver a entrar

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud» y la barra se para al 15 %, al 30 % o al 62 %. No hay mensaje. «Retomar» no cambia nada, y
mientras tanto el teléfono no sincroniza con la nube. Lo que pasa por debajo es que mi sesión de la nube caducó, pero
la pantalla no me lo dice ni me ofrece volver a entrar.

## Por qué pasa (medido el 2026-09-16)

Las fases de la vuelta anteriores al montaje del espejo tratan la sesión caducada como un corte retomable sin evento,
y ninguna deja rastro para la pantalla:

| Fase (barra) | Qué hace con la sesión caducada | Dónde |
|---|---|---|
| `reverseClaimLeader` (15 %) | `return false`, sin evento | `MigrationRunner.driveReverseClaim`, `case .sessionExpired` |
| `reverseDrainAll` (30 %) | la lee como `.transient` | `MigrationWorkExecutor.reverseDrainOnce` |
| `reverseVerify` (50 %) | la lee como `.networkTimeout` y gasta reintentos de red; al tope va a `reverseFailedRollback` con `.reverseRollback`, que con la sesión caducada lanza y queda pendiente | `MigrationWorkExecutor.verify`, `execute(.reverseRollback)` |
| `reverseFreezeBackend` (62 %) | `false`, sin evento | `MigrationWorkExecutor.freezeBackendForReverse` |

Ninguna de esas fases es estable, así que el motor de la nube no corre (`MigrationRuntimeGate.isDomainStablePhase`) y el
aviso de «vuelve a entrar» de Ajustes (`syncNeedsSignIn`) no sale: solo se enciende con el runtime en
`.stoppedUntilSignIn`, y la tarjeta que se pinta es la de progreso. La ida ya separa este caso con
`MigrationRunner.lastClaimBlocker = .sessionExpired`; la vuelta no tiene equivalente.

## Qué no es

No es el rechazo del servidor: eso lo cerró `reverse-claim-rejection-has-no-way-out-in-the-client`, que dejó la sesión
caducada y la red fuera a propósito (la red sí se arregla esperando).

## Criterios de aceptación

- [x] Con la sesión caducada en cualquiera de las cuatro fases, la pantalla dice que hay que volver a entrar y ofrece
      hacerlo, en vez de una barra muda.
- [x] Volver a entrar retoma la vuelta desde donde estaba.
- [x] En `reverseVerify` la sesión caducada no gasta los reintentos de red ni acaba en un fallo con el abort pendiente.
- [x] Tests por fase, con mutante.

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` — el rechazo del claim, que ya tiene salida.
- `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` — la otra cara: leer como caducada una sesión que
  solo está sin red.

## Hecho el 2026-09-17

### Qué cambia para la persona

- **Si la sesión de la nube caduca durante «Volver a iCloud», la pantalla lo dice y ofrece volver a entrar.** Debajo de
  la barra aparece «Tu sesión caducó. Vuelve a entrar para terminar de volver a iCloud.» con un botón «Iniciar sesión»,
  el mismo que ya usa la sección de sincronización de esa pantalla. Antes la barra se quedaba parada al 15 %, al 30 %,
  al 50 % o al 62 % sin una palabra, y «Retomar» recibía lo mismo una y otra vez.
- **Al entrar, la vuelta sigue donde estaba.** No hay un segundo gesto que buscar: el botón firma y retoma. Y si la
  sesión seguía viva —el caso más común: el servidor rechaza un token que aún no había caducado— **se arregla sola sin
  pedir nada**: renueva por dentro y sigue.
- **Si se entra con otra cuenta, la vuelta NO se retoma.** Lo dice («Entraste con otra cuenta…») y se queda donde
  estaba, intacta. Sin eso, elegir la cuenta de al lado en el selector de Google escribía los datos de una persona en
  la cuenta de otra.
- **Y el aviso se va solo** en cuanto la vuelta vuelve a avanzar.
- **Quedarse sin cobertura NO pide volver a entrar.** Es el mismo cuidado que cerró
  `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry` el día anterior: si el servidor de sesiones no
  contesta pero la sesión sigue guardada, la vuelta espera y reintenta sola, como siempre.
- **La vuelta ya no se rinde por esperar a una sesión.** En el paso de verificación, la sesión caducada gastaba el
  presupuesto de reintentos de RED y al agotarlo declaraba la vuelta fallida, dejando además pendiente el aviso al
  servidor que reactiva la nube —un aviso que con la sesión caducada tampoco podía salir—. Ahora espera a que la
  persona entre.

### Qué se tocó

- `MigrationRunner`: `ReverseStepOutcome.sessionExpired` y `VerifyProbe.sessionExpired`; `freezeBackendForReverse` pasa
  de `Bool` a `ReverseStepOutcome`; `lastReverseSessionExpiry` (en memoria, molde de `lastReverseUploadSample`) con
  `noteReverseSessionExpiry` como único escritor y `drive()` como único borrador. `driveReverseVerify` corta SIN evento.
- `MigrationWorkExecutor`: `performReverseClaim` y `freezeBackendForReverse` separan el token ausente con
  `session.canRenewSession`; `reverseDrainOnce` y `verify` dejan de colapsar el `.sessionExpired` del push y del pull.
- `CloudMigrationController`: `reverseSessionExpiry` / `reverseNeedsSignIn` y `signInToResumeReverse()`, que rescata
  con `forceRefreshAccessToken()` antes de firmar, ata la firma al `sub` de origen y toma `isWorking` antes del primer
  `await`.
- `StorageSettingsView`: caption y botón en la tarjeta de progreso.
- `L10n` + 16 idiomas: dos claves, `storage.progress.reverseNeedsSignIn` y `storage.errors.reverseSignInOtherAccount`.
  El botón reusa `storage.sync.signInButton`.
- `MetricsService`: canario `cloudReverseBlockedByExpiredSession` (`canaryOnce`, detail = la fase) y breadcrumb
  `CloudSyncReverse blockedByExpiredSession`.

### Cómo se verificó

- **Build ×2** (`Yala` y `Yala Dev`), en verde.
- **Unit**: `MigrationRunnerTests` + `MigrationWorkExecutorTests`, **161 casos en 2 suites, 0 fallos**, leído de
  `Test run with` y del result bundle.
- **Review adversarial con cuatro lentes** (máquina y journal · sesión y transporte · pantalla y tests · las reglas
  de área leídas CONTRA el diff). **Tumbó cuatro cosas mías, y la primera era de publicación:**
  1. **El botón no firmaba en el caso principal.** El belt de «sesión viva» que copié de `signInToResumeSync`
     comprobaba `hasSession && accessToken() != nil`, y con un 401 del gateway sobre un token aún vigente los dos son
     ciertos: saltaba la firma, retomaba con el token rechazado y recibía el mismo 401. El botón que ofrece entrar no
     entraba. Ahora el rescate es `forceRefreshAccessToken()`, que rota de verdad.
  2. **La firma no estaba atada al `sub`.** Este camino no hereda el gate de identidad de su hermano —que termina en
     `handleBecameActive()`—, y `reverseDrainOnce` sube un outbox que no lleva dueño. Con el chooser de Google, elegir
     la cuenta de al lado escribía el corpus de una persona bajo el `sub` de otra.
  3. **`isWorking` se tomaba después del primer `await`**, así que el re-kick de 30 s se colaba en medio y los dos
     pases corrían encima.
  4. **La caption iba tercera en la cadena**, detrás de una rama cuyo tope de 300 s la deja encendida a propósito: una
     vuelta parada por la sesión decía «esperando a que iCloud termine…» —falso— con el botón útil apagado debajo.
     Ahora va primera.
  Y cazó **dos tests míos que no podían fallar**: el del presupuesto de red sembraba `2` diciendo que el tope era `3`
  cuando es `8` (dos de sus tres aserciones pasaban con el bug dentro), y la tercera aserción de la tabla por fase era
  inerte en los cuatro casos. Los dos corregidos, y añadido el control del 403 que faltaba.
- **13 mutantes, los 13 cazados.** Uno por fase en el runner (no anotar), el verify volviendo a gastar presupuesto de
  red, los cuatro colapsos del executor (push y pull × drain y verify), el 401 del freeze leído como red, las dos
  puertas del token ausente devueltas a «siempre caducada», y el borrado entre pasadas.
- **Dos mutantes de la primera tanda SOBREVIVIERON y cambiaron el diseño**, que es lo que aportaron: (1) el drain que
  colapsa `.sessionExpired` salía verde porque los tests del runner usan el fake y **no había ningún test del executor
  para `reverseDrainOnce`** — ahora lo hay, con su control de que un 5xx sigue siendo red; (2) el `note(nil)` del claim
  aceptado era **redundante**: desde ahí toda continuación pasa por otro escritor, así que quitarlo no cambiaba nada
  observable y ningún test podía cazarlo. La respuesta no fue añadir un test sino quitar las doce líneas y dejar **un
  borrador único** al entrar en `drive()`.

### Residuales, con ticket

- `reverse-before-mount-has-no-way-to-abandon-the-return` (medium) — **el más importante de los cuatro.** Las cuatro
  fases salen solo por éxito y la tarjeta no ofrece cancelar en ninguna: un `otherLeader` en el freeze, una cuenta
  suspendida o una cuenta a la que ya no se puede entrar dejan la vuelta parada con el motor de la nube apagado. Este
  ticket **cierra la última puerta automática que quedaba** —la degradación de `reverseVerify`, que su criterio 3
  pedía quitar— sin abrir otra; el terminal viejo tampoco funcionaba (llegaba con `.reverseRollback` pendiente, que
  con la sesión caducada lanza en cada resume), así que no es una regresión de desenlace, pero el hueco queda escrito.
- `reverse-zombie-sweep-reads-an-expired-session-as-network` (low) — la misma forma una fase más tarde, ya con el
  espejo montado. Acotado a propósito: el ticket nombraba las fases anteriores al montaje.
- `neutral-mount-wiring-scan-is-red-on-2-1` (medium) — **no es de este cambio**: un source-scan de cableado que falla
  igual en un worktree limpio desde `HEAD`, medido. Se abrió porque lo encontró la suite completa de aquí.
- `forward-verify-reads-an-expired-session-as-network` — la IDA sigue tratando la sesión caducada como red en
  `verifying`: gasta reintento y al tope degrada a `failedRollback`. Es D6 del Paso 0, alcance aparte, y está fijado
  con un test para que el trato no se caiga en silencio.
- **`.accountUnavailable` (403, cuenta suspendida) sigue leyéndose como red** en el drain y en el verify, como hasta
  hoy. No es una sesión que renovar y ofrecer «Iniciar sesión» ahí mandaría a un gesto que no cambia nada; separarlo
  pide decidir qué se le dice.
- **La observación vive en memoria**, así que en un proceso nuevo cuyo resume de arranque no llegue a producirla, la
  tarjeta enseña la barra de siempre hasta el primer re-kick (≤30 s con la pantalla abierta). Decidido en D3.

## QA en iPhone

**Por qué en iPhone:** hace falta una cuenta en la nube de verdad, y el simulador no la crea sin el secreto de attest
(`.claude/rules/gateway-attest.md`). La sesión se caduca en el servidor, que es lo que el simulador tampoco puede.

**Montaje:** un iPhone de pruebas con `Yala Dev` desde Xcode contra staging, con una cuenta en la nube y algunos
movimientos. Apunta el id de la cuenta: en el SQL Editor de Supabase (staging),
`select id from auth.users where email = '<correo>';`

1. **Ajustes → «Dónde viven tus datos» → «Volver a iCloud»**, pasa las dos confirmaciones y **deja la pantalla
   abierta**.
2. **Caduca la sesión desde el servidor** mientras la barra avanza: en el SQL Editor,
   `delete from auth.sessions where user_id = '<id>';` (revoca el refresh token: la próxima renovación falla y el SDK
   borra la sesión guardada, que es la condición que separa esto de «sin red»).
3. **Espera a que la barra se pare** y, si hace falta, toca «Retomar» **dos veces**: con un residual grande el push va
   por lotes, y un 401 que llega con algún lote ya confirmado se lee como éxito parcial en esa pasada — la caption
   aparece en la siguiente. Si hace falta, Debajo de la barra tiene que salir «Tu sesión
   caducó. Vuelve a entrar para terminar de volver a iCloud.» y un botón «Iniciar sesión». **Captura, y apunta el
   porcentaje** — dice en qué fase se paró (15 % claim · 30 % drain · 50 % verify · 62 % freeze).
4. **Toca «Iniciar sesión»** y entra con la misma cuenta. La caption y el botón desaparecen y la barra sigue avanzando.
   Captura.
5. **Cierra Yala del todo y ábrela** con la sesión aún caducada (repite el paso 2 antes). Entra a la pantalla: a los
   30 s como mucho la caption vuelve sin tocar nada.
6. **El control que separa esto de «sin red»:** con la sesión BUENA, pon el iPhone en modo avión a mitad de la vuelta.
   La barra se para, pero **NO** debe salir la caption ni el botón: solo espera. Quita el modo avión y sigue.
7. **El paso 4 del ticket, con el reloj:** repite el paso 2 con la vuelta en el **paso de verificación** (50 %) y
   déjala ahí unos minutos tocando «Retomar» varias veces. La vuelta **no** puede acabar diciendo que falló.

### Criterios de aceptación de QA

- [ ] Con la sesión caducada, la tarjeta lo dice y ofrece volver a entrar, en la fase en que pille.
- [ ] Al entrar, la vuelta sigue desde donde estaba y el aviso desaparece.
- [ ] Sin red y con la sesión buena, NO se pide volver a entrar.
- [ ] La vuelta no se declara fallida por insistir con la sesión caducada.
- [ ] El aviso vuelve tras cerrar y abrir Yala.

7. **La cuenta equivocada.** Con la sesión caducada y una cuenta de Google, toca «Iniciar sesión» y elige en el
   selector **otra** cuenta de Google. Tiene que salir «Entraste con otra cuenta. Vuelve a entrar con la cuenta desde
   la que empezaste a volver a iCloud.» y la barra **no** debe moverse. Captura. Luego repite con la correcta y
   comprueba que sigue.
8. **El rescate silencioso.** Con la sesión VIVA pero un token que el servidor rechace (si puedes provocarlo), toca
   «Iniciar sesión»: no debe salir ninguna pantalla de firmar — la vuelta sigue sola.

- [ ] Entrar con otra cuenta lo dice y NO retoma la vuelta.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Depende de borrar la sesión en el servidor justo mientras avanza la barra. Lo cubren 161 casos y 13 mutantes.
