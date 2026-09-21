---
id: restore-back-and-reenter-closes-the-live-session-window
status: qa
priority: high
area: "welcome, icloud, restore"
created: 2026-09-20
updated: 2026-09-21
qa-status: needs-testing
source: "review adversarial (lente de concurrencia y ciclo de vida) de `restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-20"
---

# Salir de Restaurar y volver a entrar apaga la ventana del intento que sigue vivo

## El problema, en lenguaje de usuario

Toco «Restaurar desde iCloud», veo la barra unos segundos, me lo pienso y toco atrás. Vuelvo a
entrar y la búsqueda empieza otra vez. Minuto y medio después, mientras mi histórico está bajando,
la app vuelve a comportarse como si no hubiera ningún restore en marcha — y el guard de frontera de
cuenta se cierra sobre el dueño legítimo con su propio import a medias.

## Medido (2026-09-20)

El latch de la sesión de restauración es **asimétrico**:

- `Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift:39` — el encendido es idempotente:
  `guard restoreStartedAt == nil else { return }`. La segunda entrada NO reabre la ventana, hereda
  la de la primera.
- `:51` — el apagado es **incondicional**: `restoreStartedAt = nil`. Lo llama cualquier flujo que
  termine, incluido uno abandonado.
- `Yala/Services/iCloudSyncService.swift:538-560` — `forceFetchAndWait` resuelve su
  `withCheckedContinuation` solo por la notificación o por su `Task { sleep(timeout) }` interno:
  **no observa cancelación**. Un `runTask` cancelado sigue clavado ahí hasta agotar el tope.
- `Yala/App/Views/Onboarding/RestoreProgressView.swift` — `noteRestoreFinished()` va antes del
  `guard !Task.isCancelled`, a propósito y con su test
  (`ICloudRestoreSignalWiringTests`): así un desmontaje no se lleva el apagado por delante. Esa
  decisión es correcta para UN flujo y es justo la que produce este defecto con DOS.

Secuencia: entrar (t=0, ventana abierta) → atrás a los 5 s (el `runTask` queda cancelado pero
dentro de la continuation) → volver a entrar a los 10 s (`noteRestoreStarted` es no-op) → a t≈90 s
el `runTask` abandonado despierta y apaga la ventana del flujo vivo.
`ICloudRestoreInProgressLogic.swift:71` la lee `false` en el acto.

## Por qué sube de prioridad ahora

Es anterior al ticket del que sale, pero ese cambio **empuja justo ese gesto**: el estado nuevo
`.importIncomplete` dice «vuelve a buscar en un momento», y salir y volver a entrar en esa pantalla
es gratis.

## Criterios de aceptación

- [x] Un flujo abandonado no apaga la ventana de otro que sigue vivo.
- [x] La simetría queda declarada: el apagado se acota al intento que lo encendió (token por
      intento, acuñado por el propio encendido).
- [x] La garantía que `ICloudRestoreSignalWiringTests` ya protege —el apagado antes del guard de
      cancelación— sigue en pie por su motivo, y su scan se ancló al literal con token.

## Paso 0 — el árbol de decisiones, resuelto antes de escribir (2026-09-21)

**D1 · Cómo se acota el apagado: token por intento, no contador de entradas.** El CA deja elegir. El
contador resuelve el escenario del ticket pero pierde precisión en el orden contrario: si el flujo
VIVO termina primero y el abandonado despierta después, el contador deja la ventana abierta el
resto del tope —hasta 85 s con un guard de frontera de cuenta entornado sin nada que lo justifique—.
El token cierra exacto en los dos órdenes y no tiene contador que se pueda desbalancear.

**D2 · El encendido ACUÑA token nuevo y CONSERVA el reloj.** Son dos cosas distintas y el ticket las
mezcla en «idempotente». Lo que no puede reiniciarse es `restoreStartedAt`, porque el tope duro
dejaría de ser un tope (ya tiene test: `restartingTheSearchDoesNotExtendTheWindow`). Lo que SÍ tiene
que cambiar en cada entrada es el DUEÑO: sin token nuevo los dos intentos comparten identidad y el
token no distingue nada. Dueño = el último que entró; el anterior pierde el derecho a cerrar.

**D3 · El token no se puede fabricar fuera del latch (`FlowToken.init` `fileprivate`), y esa es la
diferencia entre un invariante que comprueba el compilador y uno que comprueba un `grep`.** Con un
`UUID` desnudo —o con una fábrica pública— el mutante `RestoreProgressView(flowToken: .init())`
compila y deja el ticket deshecho con la suite en verde. Con el `init` cerrado no compila
(verificado). Misma familia que el `restoreInProgress: Bool` sin default. **Y tiene un segundo
efecto que decidió el diseño de D4:** si nadie puede fabricar un token, entonces ANTES de
`noteRestoreStarted()` no hay ninguno, y eso convierte «no hay token» en un estado que el compilador
sabe distinguir.

**D4 · La espera no se monta hasta que hay intento, y el token llega por MONTAJE, no por re-disparo.**
`state` nace en `.searching`, así que la pantalla de progreso se monta en el PRIMER render — antes de
que `startSearch()` haya mirado iCloud ni el wipe. Se probaron dos formas de que el token llegase a
tiempo y la primera se descartó **por una medición**:

  · **Descartada: `flowToken` opcional en la pantalla + `.task(id: flowToken)`.** Apoya la corrección
    en que SwiftUI vuelva a disparar un `.task` al cambiar su `id`, y si eso no ocurre la búsqueda no
    arranca NUNCA: la pantalla se queda girando. No hay forma barata de medirlo —la pantalla de
    Restaurar no tiene XCUITest que entre en ella— y razonar sobre el orden de dos `.task` es
    exactamente lo que este repo no acepta como prueba.
  · **Elegida: `if let flowToken { RestoreProgressView(flowToken: flowToken) }`.** El token pasa de
    `nil` a un valor ⇒ SwiftUI **monta** la vista por primera vez ⇒ su `.task` corre con el token
    puesto. Montaje, no re-disparo. Nada depende del orden de los dos `.task`.

  Dos cosas que esto cierra además, y las dos las cazó la review adversarial:

  · **El apagado ya no puede correr ANTES del encendido.** Si el espejo ya importó y está quieto,
    `waitForImportQuiescence` vuelve **sin suspenderse**: con la pantalla montada en el primer render,
    su `noteRestoreFinished` podía llegar antes de que `startSearch()` registrara el token, dejando un
    dueño huérfano y la ventana abierta hasta el tope de 600 s. Hoy el montaje es posterior al
    registro por construcción.
  · **El bug del ticket tenía una segunda puerta, dentro de UNA sola pantalla.** Desde el 2026-09-20
    `.iCloudDisabled` ofrece «volver a buscar». Quien entraba con iCloud Drive apagado ya había
    arrancado una espera de 90 s en el primer render; al encender iCloud y recargar tenía **dos
    esperas vivas**, y la fantasma apagaba la ventana de la buena. Sin la puerta, este ticket habría
    cerrado el camino de «atrás» y dejado ese otro abierto.

**D5 · `forceFetchAndWait` NO se hace cancelable en este ticket, y es una decisión, no un olvido.**
El CA3 pide que el flujo abandonado no pueda tumbar al vivo: con el token no puede, y eso se mide con
un test de comportamiento. Que además siga clavado hasta el tope es un defecto propio —retiene un
observer y un `Task` de sleep, y su `refresher` hermano no hereda la cancelación— pero vive en una
primitiva que usa el ARRANQUE de la app (`AppBootstrapper`, dos call-sites) y cuyo modo de fallo al
reescribirla es crash (doble `resume`) o cuelgue (ninguno). Va a ticket propio:
`force-fetch-and-wait-ignores-cancellation`.

## Qué se hizo (2026-09-21)

- `ICloudRestoreSessionSignal.noteRestoreStarted()` devuelve un `FlowToken` y
  `noteRestoreFinished(_:)` solo cierra si es el dueño vigente. Se retiró `_testSetStartedAt`, que no
  tenía un solo llamante en el repo.
- `WelcomeRestoreView` guarda el token del intento y **no monta la espera sin él**.
- `RestoreProgressView` recibe el token y cierra con él.
- **6 mutantes, 6 muertos**: apagado incondicional · encendido que reusa el dueño · reloj reiniciado ·
  saltarse la puerta encendiendo desde el body · apagar el latch desde la puerta de Grupos · fabricar
  un token fuera del latch (éste no compila).
- Review adversarial de dos lentes (ciclo de vida · cobertura y regresión) + la rule de área: 10
  hallazgos, todos atendidos. Los dos de más peso —el apagado antes del encendido y la segunda puerta
  de `.iCloudDisabled`— cambiaron el diseño.

## Device-QA (iPhone, CloudKit real)

**Por qué en iPhone y no en simulador:** el defecto necesita que el import de CloudKit TARDE, y en el
simulador CloudKit no existe. Hacen falta un Apple ID con histórico grande (miles de movimientos) y,
para el paso 4, poder apagar iCloud Drive.

Antes de empezar: instala el build sobre el teléfono **sin borrar la app**, y ten a mano el
cronómetro — los pasos 3 y 5 se miden a los 90 s.

1. **Prepara.** Borra Yala del iPhone e instálala de nuevo (hace falta un store local vacío). Al
   abrir, elige «Ya tengo una cuenta» → «Restaurar desde iCloud». Tienen que aparecer el círculo y
   los contadores subiendo.
2. **Sal y vuelve.** A los ~5 s toca la flecha de atrás. Vuelve a entrar en «Restaurar desde iCloud».
   La búsqueda arranca otra vez y los contadores siguen subiendo. *(Esto es el gesto del ticket.)*
3. **EL PASO QUE DECIDE.** Con los contadores todavía subiendo, espera a que pasen **90 s desde el
   paso 1**. Toca atrás y entra en «Ya tengo una cuenta» → la card de tu cuenta (Apple o Google).
   **No debe salir la pantalla de «estos datos son de otra persona»**: son tus datos y los estás
   bajando tú. Si sale, el arreglo no llegó.
4. **La segunda puerta (iCloud Drive apagado).** Ajustes de iOS → tu nombre → iCloud → apaga iCloud
   Drive. Borra Yala e instálala otra vez, entra en «Restaurar desde iCloud»: tiene que salir el
   aviso de activar iCloud. Vuelve a Ajustes, **enciende** iCloud Drive, vuelve a Yala y toca el
   botón de recargar de arriba a la derecha. La búsqueda arranca.
5. **EL OTRO PASO QUE DECIDE.** Espera a que pasen **90 s desde que entraste en el paso 4** con los
   contadores todavía subiendo, y repite la comprobación del paso 3: **no debe salir** la pantalla de
   datos ajenos. *(Este camino lo abrió el botón de recargar de `.iCloudDisabled`, del 2026-09-20.)*
6. **Control de que no se rompió el recorrido normal.** Deja que la búsqueda termine y pulsa lo que
   ofrezca («Continuar» si encontró datos). Tienes que entrar a la app con tu histórico.
7. **Control del reintento.** En una pantalla que ofrezca «volver a buscar» (por ejemplo «Seguimos
   trayendo tus datos»), tócalo: la búsqueda tiene que arrancar de cero y llegar a un desenlace, no
   quedarse girando.
8. **Control del teléfono borrado.** Si acabas de usar «Empezar desde cero» en este teléfono, entra a
   «Restaurar desde iCloud»: tiene que salir el aviso de que este dispositivo se borró, **sin**
   pasar por el círculo de búsqueda.

## Relación con otros tickets

- `restore-says-no-data-when-the-icloud-import-never-settled` — de donde sale.
- `restore-empty-state-resolution-cannot-be-cancelled` — el otro «la cancelación no cancela» de la
  misma pantalla.
