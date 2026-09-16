---
id: groups-tab-does-not-say-this-phone-cannot-sync-groups
status: done
priority: low
area: "groups, attest, copy"
created: 2026-09-15
updated: 2026-09-15
source: "decisión de Jürgen en `groups-phone-that-never-attests-is-told-to-retry-forever` (2026-09-15): el aviso fijo, a ticket propio"
---

# Un teléfono sin App Attest no se entera de que sus cambios de grupos no llegan hasta que intenta salir

## El problema, en lenguaje de usuario

Edito gastos de un grupo desde este teléfono. Nadie del grupo los ve, y la app no me dice nada. Solo me entero cuando
intento cerrar sesión, desasociar la cuenta de grupos o salir del grupo: ahí me dice que este teléfono no puede
sincronizar mis grupos.

## Lo medido (2026-09-15)

- Desde `groups-phone-that-never-attests-is-told-to-retry-forever` el teléfono tiene un veredicto terminal
  (`GroupsAttestStreakStore.isTerminal`: 24 h y 3 rechazos sin un solo acierto). Lo leen los cierres de sesión, el
  desasociar y salir de un grupo. Ninguna pantalla lo enseña sin que la persona haga uno de esos gestos.
- El canal personal tampoco tiene aviso fijo: su veredicto terminal solo emite el canario
  `cloudSyncBlockedByAttestUnavailable` (`CloudSyncRuntime.performCycle`). El ticket de origen daba por hecho un banner
  que no existe.
- El canario `groupsAttestTerminal` cuenta cuántos teléfonos llegan al veredicto: con ese número se puede decidir si
  merece pantalla.

## Lo que hay que decidir (Jürgen)

1. Un aviso fijo en la pestaña Grupos mientras el veredicto sea terminal: «Este teléfono no puede sincronizar tus
   grupos», y qué puede hacer la persona.
2. Esperar al canario `groupsAttestTerminal` y decidir con el número.
3. Dejarlo: el aviso ya sale en los gestos que pueden perder algo.

## Decisión Jürgen (2026-09-15)

**Opción 1:** aviso fijo en la pestaña Grupos mientras el veredicto sea terminal. Mismo texto que el aviso honesto de la nube («Este teléfono no puede sincronizar tus grupos»), y qué puede hacer la persona.

## Hecho el 2026-09-15 — opción 1

**La pestaña Grupos ya lo dice sola.** Mientras el veredicto de App Attest sea terminal, encima de la lista hay un
aviso fijo: «Este teléfono no puede sincronizar tus grupos», y debajo, qué pasa y qué se puede hacer — «Lleva más de
un día sin conseguir la verificación de seguridad que pide nuestro servidor. Lo que edites aquí no llega al grupo:
usa otro teléfono mientras tanto.» Antes, esa misma persona podía editar gastos durante días sin que nadie del grupo
los viera y sin que la app dijera nada, hasta que intentaba cerrar sesión, desasociar o salir de un grupo.

**El título es el MISMO que el de esos gestos** (`groups.errors.attestUnavailableTitle`, del #173). La avería se
llama igual en todas partes a propósito: dos frases distintas para un solo fallo dejan a la persona pensando que son
dos cosas. Lo que cambia es el cuerpo: los gestos dicen qué no se pudo hacer, y este ofrece lo único cierto que hay.

**Sin X y sin botón.** Es el único de los tres avisos del tab que describe un estado que sigue ahí después de leerlo,
así que descartarlo solo serviría para esconderlo; y no hay ninguna acción que lo arregle desde este teléfono —
reintentar es exactamente lo que lleva un día fallando.

### Cuatro condiciones, no una, y las tres que sobraban al enunciado NO sobran

`GroupsAttestTabNoticeLogic.showsNotice` pide veredicto terminal **Y** Grupos compilado **Y** sesión en la nube viva
**Y** el consent de Grupos aceptado para esa sesión.

El ticket pedía «mientras el veredicto sea terminal», y medido, ese enunciado literal deja el aviso MINTIENDO en tres
poblaciones reales. La racha describe al TELÉFONO: sobrevive al cierre de sesión a propósito
(`GroupsAttestStreakStore` no está en `DataWipeService.removeUserPreferenceKeys`, porque cerrar sesión no arregla el
attest) y desde el #175 la escribe **también el motor personal**, que no sube un solo gasto de grupo.

- **Sin sesión en la nube.** Quien cerró sesión ayer vería «este teléfono no puede sincronizar tus grupos» encima de
  un empty state que le está pidiendo crear su cuenta: el aviso señalaría al culpable equivocado.
- **Con Grupos sin compilar.** La racha sería entera del motor personal. Anunciar una avería de Grupos donde Grupos
  no existe es inventarla.
- **Sin el consent de Grupos aceptado.** Lo cazó la review: esta persona puede tener la racha sin haber tocado Grupos
  nunca, y el tab le está ofreciendo justo aceptar el consent. Encima de eso, decirle que sus cambios de grupos no
  llegan es la misma mentira que la primera.

**Y el término del canal es la capacidad COMPILADA, no el getter compuesto — ese fue el hallazgo más caro de la
review.** `CloudSyncFlags.groupsBackendEnabled` es `compilado && remoto`, y su propio docblock separa las dos clases
de call-site: las ENTRADAS leen el compuesto (es lo que el kill-switch existe para cortar) y los TEARDOWNS leen la
capacidad compilada, porque el término remoto **es fail-closed ante un snapshot ausente o corrupto** y no es testigo
del corpus de este teléfono. Este aviso es de la segunda clase. Con el compuesto, un teléfono restaurado desde una
copia de iCloud —que hereda la racha y no la key de attest— se quedaba **sin aviso en su primer arranque**, mientras
el cierre de sesión sí se lo enseñaba: el bug del ticket, vivo, en la población más probable.

### Cuándo se vuelve a mirar, que es la otra mitad — y donde el primer intento se quedó corto

`isTerminal()` lee `UserDefaults` —que no repinta ninguna vista— y **depende del reloj**: una racha de ayer se vuelve
terminal sin que nadie escriba nada. Así que el aviso no se lee en el `body`; vive en un `@State` que se recalcula en
**cinco** momentos. Cuatro son gestos de la persona: entrar al tab, el refresco que ese `onAppear` lanza, volver de
background (el salto de reloj) y el pull-to-refresh (el «inténtalo otra vez», cuyo ciclo puede contar otro rechazo o
borrar la racha con un 200). Un test los **cuenta**, no los afirma.

**Y solo el veredicto vive en el `@State`.** Las otras tres se leen VIVAS en el body, como hacen sus vecinas del
empty state, y eso cierra dos huecos que la review midió: iniciar sesión desde el CTA de la lista no sacaba el aviso
—ese sheet se cierra en sitio, sin `onAppear`— y una sesión que el SDK borra en caliente lo dejaba puesto, culpando
al attest de lo que ya era una sesión caducada.

**El quinto momento lo añadió una medición, y es el que cierra el hueco de verdad.** Con solo los cuatro, el XCUITest cayó: el
aviso no salía. La causa no era el fixture. Medido en el simulador con dos arranques seguidos:

| Arranque | Racha al arrancar | ¿Sale el aviso? |
|---|---|---|
| La racha ya estaba en disco | presente | **sí** |
| La racha se escribe un segundo después | ausente | **no** |

O sea que el aviso se perdía exactamente el caso que más importa: **el 401 llega con la pestaña delante**, que es
donde está la persona cuando edita gastos. Con solo gestos, se enteraba al salir y volver.

El arreglo va **en el escritor, no en el lector**: `GroupsAttestStreakStore` emite `didChangeNotification` cuando la
racha cambia en disco —y solo entonces: un rechazo de la misma hora, que no suma, no anuncia nada— y la pestaña la
escucha. Así vale para los cuatro escritores de la racha (push, pull y RPC de Grupos, y la puerta del motor personal)
sin que ninguno tenga que acordarse de la pestaña.

### Ficheros

| Fichero | Qué cambia |
|---|---|
| `Yala/App/Logic/GroupsAttestTabNoticeLogic.swift` | **Nuevo.** La decisión, pura: las cuatro condiciones. |
| `Yala/Services/CloudSync/Groups/GroupsAttestStreakStore.swift` | `didChangeNotification`: el escritor avisa cuando la racha cambia. |
| `Yala/App/Views/Groups/GroupsContainerView.swift` | El aviso como tercer `safeAreaInset` (el más arriba), su `@State` y el recálculo en los cinco momentos. |
| `Yala/Utils/L10n.swift` + 16 `.lproj` | `groups.attestTerminalBanner`, el cuerpo. El título se reusa. es-AR en voseo (el fichero es voseo 167 a 34). |
| `Yala/App/UITestHooks.swift`, `Yala/App/AppBootstrapper.swift`, `Yala/App/UITestEphemeralDefaults.swift` | `-uitest-groups-attest-terminal`: siembra la racha por el camino de producción, y bajo uitest la racha entera se desvía a una suite propia. |
| `YalaUITests/Support/XCUIApplication+Yala.swift` | El arg, NOMBRADO (un typo suelto se ignora en silencio). |
| `YalaTests/GroupsAttestTabNoticeTests.swift`, `YalaUITests/Flows/GroupsAttestTerminalBannerUITests.swift` | **Nuevos.** |
| `qa/coverage-index.json`, `.claude/rules/gateway-attest.md` | Área `groups-backend-g2-sync-channel` y la regla durable. |

## Cómo se verificó

- **Unit** — `GroupsAttestTabNoticeTests`: la tabla entera de las 16 combinaciones de las cuatro condiciones, más un
  source-scan del cableado que la tabla NO ve: que el recálculo lee las tres fuentes canónicas (un mutante que fije
  `hasLiveSession: true` deja la tabla entera en verde), que el banner está gateado por su estado y montado en el
  tab, que las llamadas al recálculo son **cuatro contadas**, y la paridad del nombre del arg de test entre el
  lanzador y `UITestHooks`.
- **XCUITest** — `GroupsAttestTerminalBannerUITests`, dos casos. Con sesión y la racha sembrada, el aviso sale sin
  que nadie toque nada. Con la **misma racha** y sin sesión, no sale — y se lanza con la racha puesta a propósito:
  una aserción negativa sobre un input que ya garantiza la ausencia no prueba nada.
- **El seam no finge el veredicto.** `-uitest-groups-attest-terminal` escribe tres rechazos por el camino de
  producción (`GroupsAttestStreakStore.recordRejection` a 25 h, 24 h y 23 h) y deja decidir a
  `GroupsAttestVerdictLogic`. Un seam que devolviera `isTerminal = true` dejaría ciegos a los casos
  (`.claude/rules/testing.md`). Un test aparte comprueba que esos tres relojes producen de verdad un veredicto
  terminal, y avisa de que **están en el borde exacto**: subir el intervalo de conteo por encima de la hora dejaría
  la racha en un solo rechazo y el aviso no saldría nunca.
- **Y bajo uitest la racha entera se desvía a una suite propia** (`UITestEphemeralDefaults.applyEphemeralAttestStreak`,
  molde de las tres purgas vecinas). Lo cazó la review: la racha no está en `removeUserPreferenceKeys` a propósito, así
  que `-uitest-reset` no la borra, y una corrida con el seam dejaba el veredicto terminal puesto para **todo arranque
  manual** del simulador y para el host de unit tests, que comparte bundle — los gestos de cierre y de salir de un
  grupo lo leen y ofrecerían perder los cambios sobre un teléfono que atesta perfectamente. El desvío cubre además
  toda escritura de la corrida, no solo la del seam.
- **El aviso del store, con comportamiento y no con un grep** — `GroupsAttestStreakNotificationTests`: un rechazo que
  escribe avisa, uno de la misma hora no, borrar la racha avisa y borrar cuando no hay nada no. Es el único momento de
  recálculo que no depende de un gesto, así que es el que más barato sería perder en un refactor.
- **La cuarta condición, el canal, no es ejercitable en XCUITest**: `groupsBackendCompiledCapability` es una
  constante de compilación. La cubre la tabla del unit, y un source-scan prohíbe explícitamente volver al getter
  compuesto.
- **Cuatro casos XCUITest**, no dos: con sesión sobre la lista vacía y sobre la lista **poblada** —la población real
  del bug, donde el aviso convive con las tarjetas y el buscador—, sin sesión, y sin consent.

## Lo que queda fuera

- **La transición viva en pantalla** —ver el aviso irse en el momento exacto en que un 200 borra la racha— no tiene
  XCUITest: haría falta un 401 y un 200 reales contra el gateway. Lo que sí está fijado, y en dos capas, es que el
  aviso del store se emite (unit de comportamiento) y que la pestaña lo escucha (source-scan).
- **El cruce de las 24 h con la app abierta en el tab.** La racha no cambia en disco —los tres rechazos ya estaban
  contados— así que nadie avisa: el aviso espera al siguiente gesto. Cubrirlo pediría un temporizador y el retraso
  es de minutos, no de días.
- **Este aviso es el primer consumidor del veredicto SIN el testigo del ciclo**, y es a sabiendas. Los otros tres
  exigen además que ESTE ciclo haya chocado con el attest; aquí no se puede, porque el tab es justo donde la persona
  está sin que corra nada y pedirlo dejaría el aviso mudo. ⇒ un teléfono restaurado con una racha heredada que hoy
  atesta bien ve el aviso hasta que un 200 la borre, y se lo cura él solo: el `onAppear` lanza un pull y el 200
  emite el aviso del store.
- **«Usa otro teléfono» cuando el teléfono no es el culpable.** La racha admite a propósito dos rechazos ajenos al
  aparato (el servidor de attest de Apple caído, y el fallo de base de datos que el gateway tapa como
  `yala_attest_invalid`). Con una caída de más de un día, el consejo no arregla nada. Antes eso solo se leía al
  intentar un gesto; ahora es fijo.
- **La convivencia con el chip de invitación.** Un teléfono con veredicto terminal que abre un enlace de invitación
  recibe 401 en la RPC y se queda en el chip `invite_failed_banner`, con su botón **Reintentar** justo encima de un
  aviso que dice que reintentar es lo que lleva un día fallando. No rompe nada —los tres avisos son insets apilados y
  ninguno tapa a otro, medido en la review— pero el par se lee raro. Sin decisión.
- **El aviso del canal personal.** El #175 dejó el cierre honesto en Ajustes, pero la nube personal sigue sin aviso
  fijo: su veredicto terminal solo emite el canario `cloudSyncBlockedByAttestUnavailable`. Este ticket es Grupos, y
  el hermano personal necesita su propia decisión.

## Relación con otros tickets

- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale.
- `groups-join-intent-expires-silently-after-transient-failures` — otro silencio de la misma población: la invitación
  que caduca.
