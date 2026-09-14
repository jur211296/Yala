---
id: groups-only-private-restart-skips-the-wipe-alert
status: qa
priority: high
area: "modo-nube, onboarding, groups"
created: 2026-09-10
updated: 2026-09-13
source: "review adversarial del paso 5 (`groups-only-second-launch-mounts-icloud-mirror`), lente de mount"
---

# Desde una sesión solo-grupos, «Primera vez → privado» se salta el aviso de datos existentes

## El síntoma, en lenguaje de usuario

Uso Yala solo para grupos. Cierro la sesión de Grupos («Salir de Yala en este dispositivo») y la app me
devuelve a la pantalla de bienvenida. Elijo «Es mi primera vez → Tu cuenta en tu iCloud privado». La app
me pide reabrirla, la reabro, y **entro a un onboarding de cero sin que nadie me avise de que aquí ya hay
datos** — los grupos y las categorías de la etapa anterior siguen dentro. Antes, en ese punto, salía
«Detectamos datos previos, ¿los borro?».

## Lo medido (2026-09-10)

Es una **regresión introducida por el paso 5** del rediseño, y su causa es una premisa que dejó de ser
cierta.

`ContentView`, callback `onNeedsMirrorRelaunch`, justifica saltarse el aviso así:

> «El alert de datos existentes que esa función también monta NO hace falta — **el mount neutro exige que
> no haya archivo de store**, así que en este camino no puede haber datos que confirmar.»

Eso valía con los dos términos viejos del neutro: `isFreshInstallForNeutralMount` exige que el archivo del
store no exista. **El término nuevo (`groupsOnlySessionArmed`) rompe la equivalencia**: una sesión
solo-grupos tiene archivo de store con datos dentro (categorías sembradas por `completeSetup`, filas
`SplitGroup`, transacciones puenteadas) y monta neutro igual.

Cadena: alta solo-grupos ⇒ marca armada ⇒ `CloudSessionSignOut.performPrivateReset` devuelve al Welcome
**sin relanzar** ⇒ el proceso vivo sigue montado `.neutralNoMirror` ⇒ «privado» llama a
`WelcomeFlowContainer.leaveWelcome`, y ahí `shouldRelaunch` da `true` ⇒ se va por `onNeedsMirrorRelaunch`
y **`proceed()` nunca corre** ⇒ nunca corre `startFreshPrivateOnboarding`, y con él ni el alert ni
`DataWipeService.wipeAllUserData` ni `wipeLocalGroupsDomain`. Al reabrir,
`presentNextOnboardingScreen` consume el destino y monta el onboarding sin volver a mirar
`hasExistingData`.

Antes del paso 5 ese camino montaba `.iCloudMirror` ⇒ `shouldRelaunch == false` ⇒ `proceed()` ⇒ el alert
salía y el borrado corría.

**Lo que ya se mitigó en el paso 5, y por qué no basta:** `resetOnboardingFlagsPreservingData` desarma
ahora la marca, así que el fallo **no persiste** entre arranques — al reabrir, el mount vuelve a la tabla
normal. Pero el testigo del mount del proceso VIVO ya se capturó, así que dentro de esa misma sesión el
hueco sigue abierto.

## Por qué importa

El sello de handover (`groupsDomainSealedForFreshStart`) tampoco se escribe, y en el arranque siguiente
—con el espejo ya reactivado— ese corpus **sube al iCloud del Apple ID**. Es exactamente lo que el
comentario de `ShellDataAlertsModifier` existe para impedir.

## Por dónde va el arreglo (y la decisión que hace falta)

El camino no puede a la vez relanzar (para adjuntar el espejo) y correr un borrado por filas (que con el
espejo montado exportaría los deletes). La salida natural es la misma que propone
`late-icloud-wipe-can-re-export-between-its-two-halves`: **armar el boot-wipe**
(`StorageModePersistence.armSignOutWipe`), que borra archivos **pre-mount** y es kill-safe.

**La decisión pendiente es si se le pregunta.** Hoy el borrado del camino privado va con doble
confirmación; armar el wipe en silencio sería destructivo sin aviso. Lo coherente con el paso 4 es que
este camino pase por la misma puerta (`WelcomePrivateICloudGateView`), que ya sabe validar iCloud, contar
lo que hay y pedir confirmación — pero eso lo toca, y por eso no se hizo dentro del paso 5.

## Paso 0 · lo decidido antes de escribir (2026-09-13)

**La cadena literal del ticket ya no existe, y el hueco sí.** `CloudSessionSignOut.performPrivateReset` y
`resetOnboardingFlagsPreservingData` dan **cero ocurrencias** en el árbol de hoy: el paso 9 cambió los
cierres de sesión, y el de solo-grupos pasa por `armSignOutWipe`, que borra el store personal y **retira**
la marca (`SwiftDataConfiguration.swift:665`). Por ahí no se llega.

El estado que el bug necesita —marca `groupsOnlyNeutralMount` armada · Welcome en pantalla · store
personal con filas— **sí es alcanzable**, y el camino limpio es otro: **un wipe REMOTO sobre un
dispositivo solo-grupos**. Otro device del mismo Apple ID vacía sus datos, este procesa la señal
(`performLocalWipeForRemoteSync`), `wipeAllUserData` **deja vivos los `SplitGroup`**, y las dos últimas
líneas reponen `hasShownWelcomeChooser = false` y `hasCompletedOnboarding = false` ⇒ Welcome, con la marca
intacta. El botón destructivo del alert de wipe remoto llega al mismo sitio **sin borrar una sola fila**.

**D1 · Dónde se cierra: en la puerta privada, no en el callback del relanzamiento.** Es el único punto del
camino que es un STEP del cover del Welcome, así que puede pedir confirmación sin desmontar nada — un
`.alert` del anchor de `ContentView` desmonta el cover entero (medido, `ShellDataAlertsModifier`). Ya está
delante de esta rama desde el paso 4; lo que le faltaba era mirar lo que hay **aquí**, no solo en iCloud.

**D2 · Se borra por FILAS, no armando el boot-wipe.** La premisa del ticket («no se puede borrar por filas
porque el espejo exportaría los deletes») **solo vale con el espejo montado**, y el aviso se enciende
exactamente cuando `shouldRelaunch` es `true`, que exige `.neutralNoMirror` — `cloudKitDatabase: .none`
explícito, sin espejo que pueda exportar nada. El boot-wipe traería además lo que aquí no se quiere: se
lleva la marca y las prefs enteras, y no escribe el sello del handover.

**D3 · Se pregunta, y con doble confirmación.** Mismo molde de fases que el aviso de iCloud. Sin cifras, al
revés que aquél: allí son el histórico que la persona escribió y sostienen la decisión de traerlo de
vuelta; aquí son categorías que sembró la app y grupos de la etapa anterior, y un «12 categorías» sugeriría
un trabajo propio que nadie hizo.

**D4 · El corpus REMOTO gana cuando los dos tienen datos.** Aquel aviso ofrece «traer mis datos», la única
salida que no destruye nada, y su borrado ya se lleva las filas locales por delante.

**D5 · Si a iCloud no se le pudo preguntar, la salida escribe el testigo del espejo tardío.** Sin eso, quien
borra lo suyo sin red se come el histórico del Apple ID el día que iCloud vuelva: este mismo bug por detrás.

**D6 · La activación de «Yala completo» NO pregunta** (`deviceCorpus: nil`). Allí los datos del teléfono son
de la persona que está activando, y borrárselos sería el daño contrario.


## Criterios de aceptación

- [ ] Sesión solo-grupos → cerrar sesión → «Primera vez → privado»: **sale el aviso de datos existentes**
      (o su equivalente en la puerta de iCloud) antes de cualquier relanzamiento.
- [ ] Si la persona confirma, al reabrir el store está vacío y el sello de handover escrito.
- [ ] Si cancela, no se borra nada y vuelve a la elección.
- [ ] En el arranque siguiente **no sube a iCloud** ningún dato de la etapa solo-grupos.
- [ ] El camino equivalente desde una instalación fresca (sin datos) sigue sin preguntar nada.

## Cómo se prueba

- Unit: la decisión es pura (`WelcomeMirrorRelaunchLogic.shouldRelaunch` + el predicado de datos).
- Device-QA: el único sitio donde se puede ver que iCloud no recibe el corpus viejo.

## Lo que se hizo (2026-09-13)

**El aviso vive ahora en la puerta privada**, que es un STEP del cover del Welcome y por tanto puede pedir
confirmación sin desmontar nada. `WelcomePrivateICloudGateLogic.decide` gana el término `deviceHasData`
—sin valor por defecto, para que los dos sitios que montan la puerta se pronuncien— y el desenlace
`.foundDeviceData(iCloudUnverified:)`; la vista gana sus cuatro fases con doble confirmación; y
`ContentView.performDeviceCorpusWipe()` borra filas locales + dominio de Grupos + **sello de handover**.

**El término va atado al MISMO predicado que el relanzamiento**, y no es simetría: el borrado quita FILAS,
y con el espejo montado los deletes se quedan en la History y **se exportan** — vaciarían el iCloud de la
persona en todos sus dispositivos (`.claude/rules/swiftdata-cloudkit.md`, «ARCHIVOS, nunca FILAS»). El
mount neutro es `cloudKitDatabase: .none` explícito, y es la única celda donde el aviso se enciende.

### Lo que la review adversarial cazó, y era todo MÍO

Cuatro lentes + la rule del área contra el diff. **Once defectos**, cinco de ellos ALTA:

1. **El borrado por filas con el espejo montado** (rule de área). El término no estaba acotado y el aviso
   podía salir con `.iCloudMirror`: sus deletes se habrían exportado.
2. **El arm compartido escalaba un borrado LOCAL a uno REMOTO.** `wipeDevice` armaba
   `armICloudCorpusWipe`, y ese testigo tiene dos consumidores: uno vuelve a la puerta, pero
   `runLateICloudMirrorCheck` lo **reanuda a ciegas** con `performICloudCorpusWipe()`, que borra la ZONA
   del Apple ID. Un kill a mitad acababa vaciando el iCloud de alguien que confirmó otra cosa.
3. **El borrado se saboteaba a sí mismo.** `wipeAllUserData` borra `hasCompletedOnboarding` ⇒ el `onChange`
   de `ContentView` llamaba a `presentNextOnboardingScreen`, que **consume el destino del relanzamiento** y
   monta un segundo cover sobre el terminal «reabre Yala». Con el destino consumido, `shouldExitOnBackground`
   se apaga y el relanzamiento no ocurre nunca.
4. **La celda «iCloud con datos ∧ teléfono con datos» no sellaba.** Gana el aviso remoto (ofrece «traer mis
   datos»), y su borrado dejaba los grupos vivos y el sello sin escribir ⇒ el criterio nº4 incumplido justo
   ahí. Ahora ese camino también purga y sella, dentro del guard que la activación no cruza.
5. **El copy prometía lo que el código no cumple.** «No se puede deshacer» sobre unos grupos que viven en la
   cuenta, «tus datos siguen intactos» sobre un borrado con `save()` incrementales, y «Reintentar búsqueda»
   como label de un borrado fallido. Cinco claves reescritas y dos nuevas, en los 16 locales.

Y seis más, medias: la cancelación de la `.task` se comía las consecuencias de un borrado ya hecho; la
gracia del wipe remoto se cancelaba solo en la rama de éxito (en la de fallo encendía el alert que
**desmonta el cover** y deja la pantalla negra); el conteo del teléfono se muestreaba antes del `await` de
la sonda pese a que dos docblocks lo llamaban «vivo»; las dos pantallas nuevas duplicaban `noticeShell`;
los identificadores mezclaban dos esquemas; y «Mejor no» llevaba a dos sitios distintos a una pantalla de
distancia.

**Y la red de pruebas tenía agujeros de paso**: un solo token (`deviceHasData = false`) reintroducía el
ticket entero en verde, y los dos botones de la 2.ª confirmación eran intercambiables sin un rojo — «Mejor
no» borrando. Los cierra un scan que fija el **emparejamiento** identificador ↔ acción, no la presencia.

### Una afirmación del ticket que se midió y era falsa

El ticket decía que el corpus de grupos «se re-descarga» tras la purga. Eso es del canal CloudKit, que ya
no existe. Con el canal backend **el cursor sobrevive a propósito** (`DataWipeService`, «el cursor es la
BARRERA que impide que el corpus del anterior BAJE»), así que no vuelve a bajar.

### Verificado

- Build `Yala` ✓ y `Yala Dev` ✓ — **cero warnings nuevos**, medido contra un worktree del árbol base
  (los dos que salen ya estaban ahí, desplazados de línea).
- **6797 unit en 691 suites, 0 fallos.**
- **19 mutantes puestos, los 19 los mata su test** (7 sobre la decisión y el cableado, 12 sobre la red
  nueva: el cable del medio, el swap de botones, la inversión del testigo, el `runPhase` sin su rama, el
  sello que se cae, el guard del Welcome, el copy que vuelve a prometer iCloud y el arm que revive).
- Índice de QA ✓ ratchet OK.

### Lo que queda, y es de Jürgen

- **El device-QA NO es simulable**, y el motivo está medido: la puerta sale de largo bajo `-uitest`
  (hermeticidad antes de la red) y ningún seed arma la marca del neutro solo-grupos. Guion de 9 pasos en
  `tickets/qa/device-qa-private-gate-device-corpus.md`.
- Tres tickets nuevos: `private-gate-remote-wipe-can-strand-its-arm`,
  `private-gate-device-notice-has-no-forward-exit` y
  `fresh-start-wipe-kills-unsent-group-writes-silently`.
