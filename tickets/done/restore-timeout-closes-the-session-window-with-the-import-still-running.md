---
id: restore-timeout-closes-the-session-window-with-the-import-still-running
status: done
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
updated: 2026-09-23
source: "medido durante `abandoned-restore-no-longer-clears-the-session-window-clock`, 2026-09-21 (D5 del Paso 0)"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - combinacion rara de restore largo y cuenta de nube en el mismo telefono; ICloudRestoreSignalTests
---

# El tope de 90 s cierra la ventana de sesión con el import todavía bajando

## El problema, en lenguaje de usuario

Entro a «Restaurar desde iCloud» y mis datos son muchos. A los 90 s la pantalla se rinde y me dice
«seguimos trayendo tus datos» — que es verdad: siguen bajando. Toco atrás y firmo con mi cuenta. La
app me dice que **estos datos son de otra persona**. Son míos, y de hecho están entrando en ese
mismo momento.

## Medido (2026-09-21)

`RestoreProgressView.startFlow` llama a `ICloudRestoreSessionSignal.noteRestoreFinished(flowToken)`
**gane o pierda**, o sea también cuando `waitForImportQuiescence` devuelve `false` por agotar su tope
de 90 s. Ese apagado pone `restoreStartedAt = nil`, así que
`ICloudRestoreInProgressLogic.isRestoringNow` devuelve `false` en el acto y
`CrossAccountEntryGuardLogic.decide` vuelve a `.blockedForeignData` para el dueño legítimo.

Es exactamente el mismo daño que cerró `force-fetch-and-wait-ignores-cancellation` —apagar la ventana
con el import vivo— por un eje distinto: allí lo disparaba el ABANDONO, aquí lo dispara el DESENLACE.

El estado `.importIncomplete` es la prueba de que el caso existe y es esperado: se pinta precisamente
cuando el tope se agotó **con un import de CloudKit en marcha**. La pantalla afirma que los datos
están bajando y la señal ya dijo que no.

Con `abandoned-restore-no-longer-clears-the-session-window-clock` (2026-09-21) la señal ya distingue
apagar de soltar (`noteRestoreAbandoned`), así que el mecanismo para arreglarlo ya existe: falta
decidir si `noteRestoreFinished` debe apagar en los dos desenlaces o solo cuando `settled == true`.

## Por qué no se arregló de paso

Toca la semántica de `noteRestoreFinished`, que hoy documenta «gane o pierda» como una decisión, y su
source-scan (`theProgressViewClosesTheWindowWhenTheFlowEnds`) la fija con esas palabras. Cambiarla
pide medir qué pasa con el reintento, que es la superficie a la que lleva `.importIncomplete`: si el
timeout suelta en vez de apagar, la ventana huérfana sobrevive y el reintento NO estrena reloj —lo
cual es correcto o no según lo que se decida aquí.

## Paso 0 — el árbol de decisiones (resuelto sin Jürgen, 2026-09-21)

**D1 · ¿Con qué predicado se distingue «tope agotado con import en marcha» de «sin nada que
importar»?** ~~Con `RestoreImportSettlement`, el mismo testigo con el que la pantalla elige el copy,
expuesto como derivado propio `closesTheSessionWindow`.~~ **CAÍDO — lo refutó la review adversarial del
mismo día, y era el bug del ticket sin arreglar.** Ese enum agrupa en `.inconclusive` dos poblaciones
que a esta pregunta contestan distinto: la que no vio un solo import y la que vio uno con un **error
vigente**. Y la mayoría de esos errores son retriables —`iCloudSyncService.isRetriable` da `true` a
`.networkUnavailable`, `.requestRateLimited`, `.zoneBusy` y hasta en su `default`—, con CloudKit
trayendo filas detrás de cada uno. O sea que a un restore grande con la red floja, que es el caso
NORMAL, se le apagaba la ventana con la descarga viva.

⇒ el criterio son **los dos términos crudos** y vive en
`ICloudRestoreInProgressLogic.closesTheSessionWindow(settled:hasObservedImportActivity:)`, que es el
complemento exacto de sus caminos (2) y (3): cierra si el import asentó, o si no llegó un solo
`.importEvent`. El enum del copy queda con un comentario que prohíbe volver a colgarle esto, y un
escáner lo fija.

**La lección, que es de método:** el primer diseño se defendía diciendo «no ato `closesTheSessionWindow`
a `consultsRemoteConfig` porque responden preguntas distintas» — y acto seguido lo ataba al **caso** del
que aquél deriva, que es lo mismo por la puerta de atrás. Dos derivados del mismo enum no son
independientes: comparten su forma de agrupar.

**D2 · ¿El tope agotado CON actividad pero con error vigente de CloudKit cierra?** ~~Sí.~~ **NO** — es
la misma refutación de D1. La ventana de esa población la cierran el asentamiento o la caducidad, con el
tope duro de 600 s acotándola pase lo que pase. Es el mismo residuo que el camino (3) de
`ICloudRestoreInProgressLogic` ya acepta y documenta para el import que falla.

**D3 · ¿Y `.stillImporting` con datos, que va a `.found` y no a `.importIncomplete`?** Tampoco cierra.
El predicado es el desenlace de la espera, no la pantalla que se pinta: si CloudKit sigue trayendo
filas, sigue trayéndolas también para quien ya vio su resumen.

**D4 · ¿Cómo se cumple «el reintento no re-ancla el tope duro»?** Conservando la TITULARIDAD mientras
la persona siga dentro de Restaurar. `noteRestoreStarted` ya conserva el reloj cuando hay dueño
vigente, así que basta con que el dueño no se suelte al cambiar de estado interno. ⇒ **el
`noteRestoreAbandoned` se muda de `RestoreProgressView.onDisappear` a `WelcomeRestoreView`**: el
desmontaje de la pantalla de progreso es un cambio de estado (`.importIncomplete`, `.found`, …), no un
abandono; abandonar es salir de Restaurar. Medido que el caso del ticket hermano se conserva: tocar
«atrás» desmonta `WelcomeRestoreView` en sus DOS call-sites (`ContentView.welcomeRestoreCover` y el
`case .restore` de `FullModeActivationView`), así que sigue soltando y la entrada siguiente sigue
re-anclando.

  · Descartado dejar el soltar donde está y aceptar el re-ancla: incumple el tercer criterio, y
    `hasObservedImportActivity` es un latch monótono del proceso — basta UN `.importEvent` en toda la
    vida de la app para que cada reintento estrene otros 600 s de ventana.
  · Descartado marcar en la vista un `@State` de «ya entregué»: `@State` es una caja compartida entre
    generaciones de la vista (el propio fichero documenta esa trampa con el refresher) y el guard tiene
    que vivir donde el escritor.

**D5 · ¿Hace falta un verbo nuevo en la señal?** No. `noteRestoreFinished` y `noteRestoreAbandoned`
cubren los dos desenlaces; lo que cambia es QUIÉN llama y CUÁNDO. Un tercer verbo que no tocara nada
sería ceremonia.

**D6 · ¿Qué otra salida tiene que apagar, además del final de la espera?** «Empezar desde cero», desde su
propia confirmación. **Lo destapó la review como regresión de este mismo ticket**: desde que el tope
agotado con el import vivo ya no apaga, esa salida se quedaba solo con el `onDisappear` —que suelta y no
toca el reloj—, así que la ventana se iba abierta hasta diez minutos con el guard de frontera de cuenta
entornado; antes la cerraba el apagado incondicional a los 90 s. Y es el único camino de salida donde
apagar es correcto: todo el diseño se apoya en «las filas siguen entrando», y aquí la persona acaba de
declarar lo contrario — detrás del botón está la puerta que las borra. Va en la confirmación y no en el
botón, porque el botón solo abre el diálogo y `cancel` tiene que poder volver sin haber apagado nada.

## Criterios de aceptación

- [x] Un restore que agota el tope de 90 s **con el import en marcha** no deja al dueño legítimo
      bloqueado en su propia cuenta.
- [x] Un restore que agota el tope **sin nada que importar** sigue cerrando la ventana sin esperar a
      la caducidad (no se pierde la precisión que el apagado explícito aporta).
- [x] El reintento desde `.importIncomplete` no puede re-anclar el tope duro a voluntad.

## Qué se hizo (2026-09-21)

**El apagado dejó de ser «gane o pierda».** `RestoreProgressView` llama a `noteRestoreFinished` detrás
de `ICloudRestoreInProgressLogic.closesTheSessionWindow(settled:hasObservedImportActivity:)`, con los dos
términos crudos de la espera: cierra el import que asentó y el tope agotado **sin un solo
`.importEvent`**. Habiendo visto un import, la pantalla **no llama a nada** — las filas siguen entrando y
la señal ya no puede afirmar lo contrario en el mismo instante en que la pantalla dice «seguimos trayendo
tus datos». El criterio NO es el desenlace que elige el copy: ver D1.

**Y «Empezar desde cero» apaga la ventana desde su propia confirmación.** Es la otra salida que sabe que
no queda descarga, porque la persona acaba de decirlo.

**El `noteRestoreAbandoned` se mudó a `WelcomeRestoreView`.** Era la única forma de cumplir el tercer
criterio sin inventar estado: la pantalla de progreso se desmonta también cuando el `state` de arriba
cambia —a `.importIncomplete`, a `.found`—, o sea con la persona todavía dentro de Restaurar, así que
soltar ahí dejaba la ventana huérfana y el reintento la re-anclaba. Y `hasObservedImportActivity` es un
latch monótono del proceso: basta UN `.importEvent` en toda la vida de la app para que cada «volver a
buscar» estrenase otros 600 s. Hoy la titularidad se conserva mientras la persona siga en Restaurar, y
`noteRestoreStarted` con dueño vigente no toca el reloj.

**Lo que NO cambió, y se midió:** el ticket hermano sigue en pie. Tocar «atrás» desmonta
`WelcomeRestoreView` en sus dos call-sites —las tres salidas de `ContentView.welcomeRestoreCover`
ponen `showWelcomeRestore = false`, y el `case .restore` de `FullModeActivationView` es un `switch`
que cambia de pantalla—, así que sigue soltando y la entrada siguiente sigue re-anclando con descarga
real detrás.

### La review adversarial cazó tres defectos MÍOS, y dos eran el bug sin arreglar

Tres lentes independientes sobre el diff congelado (ciclo de vida de SwiftUI · semántica del predicado ·
la red de tests), más la rule de área leída contra el diff.

1. **El predicado seguía al COPY** y le apagaba la ventana a la población del error retriable con la
   descarga viva — el bug del ticket, sin arreglar, para el caso más común de un restore grande. ⇒ D1/D2
   reescritos, criterio con los dos términos crudos.
2. **«Empezar desde cero» se llevaba la ventana abierta hasta diez minutos**, donde antes la cerraba el
   apagado incondicional a los 90 s. Regresión de este mismo ticket. ⇒ D6.
3. **Tres agujeros en mi red de tests**: el scan del `.onDisappear` no anclaba a QUÉ vista cuelga (mover
   el bloque dentro del `switch` reabría el ticket con todo en verde), el del apagado no contaba
   ocurrencias (añadir la llamada incondicional DEBAJO de la puerta pasaba), y el criterio 1 se afirmaba
   sobre un campo y no sobre `CrossAccountEntryGuardLogic`, que es donde la persona lo sufre.

Y una premisa mía que era falsa: «el desmontaje de la pantalla de Restaurar significa "me fui"». En
`FullModeActivationView` no siempre —`finishRestoreSearch` pinta su `finale` encima sin desmontar, y
`go(to:)` desmonta con la persona todavía dentro—. Hoy ninguna hace daño; el docblock ya lo dice.

### Verificado

- Build ×2 y las cuatro suites del área: **44 tests en 4 suites** (pedidas = corridas).
- Tests de comportamiento: el tope con import vivo **medido con el veredicto de
  `CrossAccountEntryGuardLogic`** (`.proceed` a los 95 s), el error retriable que tampoco cierra, el tope
  sin un solo import que sí cierra en el acto, descartar que apaga, seis reintentos de 90 s que no mueven
  el reloj más el guard bloqueando a los 601 s, e irse de Restaurar que sí suelta.
- **Mutantes**: 8 sobre el primer diseño y otra tanda sobre el corregido —criterio a constante, el `!`
  perdido, descartar sin apagar, el `onDisappear` mudado dentro del `switch`—, todos muertos.

### Guion de QA (iPhone, CloudKit Production)

El escenario **no se monta en simulador**: hace falta un histórico que CloudKit tarde más de 90 s en
bajar. Pasos:

1. En un iPhone con una cuenta de iCloud cuyo Yala tenga histórico grande (varios miles de
   movimientos), borra la app y vuelve a instalarla desde TestFlight.
2. Ábrela y elige **«Ya tengo cuenta» → «Restaurar desde iCloud»**. Espera sin tocar nada.
3. **A los 90 s la pantalla tiene que decir «seguimos trayendo tus datos»** (no «No hay datos
   asociados a tu cuenta de iCloud»). Si dice lo segundo, el import no arrancó: repite con red buena.
4. Desde ahí toca **atrás** y entra por la card de **tu propia cuenta**, firmando con el mismo Apple ID.
   ✅ **Tiene que dejarte entrar.** ❌ Si dice que los datos son de otra persona, el ticket no está
   arreglado.
5. Vuelve a Restaurar y, en «seguimos trayendo tus datos», pulsa **«volver a buscar»** cinco o seis
   veces seguidas, dejando que cada intento agote sus 90 s.
6. **Pasados unos diez minutos desde la PRIMERA entrada**, repite el paso 4. ✅ Ahora **sí** tiene que
   bloquearte: el tope duro cerró la ventana y reintentar no lo extiende. Si te sigue dejando entrar
   indefinidamente, el reintento está re-anclando el tope.
7. Control por el otro lado, con un Apple ID **sin nada en Yala**: «Restaurar desde iCloud» → a los
   90 s sale «No hay datos asociados a tu cuenta de iCloud», y entrar por la card de la cuenta se
   comporta como siempre desde el primer momento (la ventana se cerró en el acto, sin esperar a caducar).

## Residual medido (con ticket propio)

**Salir de Restaurar y volver a entrar renueva el tope duro**, porque `hasObservedImportActivity` es un
latch monótono del proceso: dos toques por vuelta, sin esperar los 90 s. No es regresión —antes el
apagado incondicional producía el mismo estreno de reloj por la otra rama del `if`— y el tercer criterio
de este ticket no lo nombraba: habla del **reintento**, que sí queda cerrado. Ticket:
`leaving-and-reentering-restore-renews-the-hard-cap`.

**Y el precio que este ticket compra, escrito para que nadie lo descubra de nuevo:** para la población
con import observado y sin asentar, la ventana pasa de cerrarse a los 90 s a vivir hasta 600 s, y dentro
de ese tramo `isRestoringNow` se recalcula vivo — así que un import de rutina del espejo puede reabrirla.
Es lo que se paga por no bloquear al dueño legítimo sobre sus propios datos, y lo acotan el asentamiento,
el tope duro y el apagado de «Empezar desde cero».

## Relación con otros tickets

- `abandoned-restore-no-longer-clears-the-session-window-clock` — de donde sale; aporta
  `noteRestoreAbandoned`.
- `force-fetch-and-wait-ignores-cancellation` — el mismo daño por el eje del abandono.
- `leaving-and-reentering-restore-renews-the-hard-cap` — el residual que deja, medido por la review.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Solo muerde con un restore de más de 90 s seguido de entrar en la nube en el mismo teléfono. Lo cubre `ICloudRestoreSignalTests`.
