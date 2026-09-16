---
id: detach-failure-looks-like-success
status: done
priority: high
area: "settings, groups, modo-nube"
created: 2026-09-11
updated: 2026-09-16
source: "review adversarial de `detach-history-replay-can-tombstone-groups-on-next-launch` (lentes de contrato y de producto)"
qa-status: not-replicable
qa-date: 2026-09-16
qa-notes: No replicable (override Jurgen 2026-09-16) - el fallo del borrado solo se alcanza con un seam uitest que cambia los stores, no con asociacion real. XCUITest pendiente en uitest-seam-for-a-seeded-groups-association
---

# Si el desasociar falla al borrar, la app dice que lo soltó y no avisa de nada

## El problema, en lenguaje de usuario

Toco «Desasociar» en Ajustes → «¿Dónde viven tus datos?» → Grupos. La pantalla me dice que ya no hay cuenta
asociada. Pero si el borrado local falló, **mis grupos siguen enteros en el teléfono** —la pestaña Grupos,
los gastos, todo— y nadie me lo dice. La app y el teléfono cuentan cosas distintas, y la que se equivoca es
la app.

## Lo medido (2026-09-11)

`CloudSessionSignOut.purgeGroupsDomainForDetach` traga el error (solo lo imprime bajo `#if DEBUG`) y
`detachGroupsAccount` sigue adelante: `GroupsAccountAssociation.shared.clear()`,
`GroupsSessionHistoryMarker.markSessionSeen()`, `WidgetDataCache.updateCache` y `phase = .idle`. La UI
(`GroupsAssociationSection`) solo muestra aviso cuando la fase queda en `.blocked`, así que `.idle` se lee
como éxito.

Estado resultante: **sesión de grupos cerrada + asociación borrada + todas las filas `Split*`, el outbox y
el cursor intactos**, sin un solo mensaje. Y como el borrado es una sola transacción con rollback, el fallo
es todo-o-nada: no queda a medias, queda **entero**, que es justo lo que la pantalla niega.

No es regresión: el comportamiento es el mismo desde el paso 10.

## El contraste que enseña la salida

Su hermano, el «Empiezo de cero» del Welcome, sí lo hace bien: `ShellDataAlertsModifier` envuelve la llamada
en `do/catch`, enseña el alert de fallo, **no navega** al onboarding y dispara el canario
`MetricsService.canary(.freshStartWipeFailed)`. El desasociar necesita las tres cosas.

## Lo que se espera

1. `purgeGroupsDomainForDetach` propaga en vez de tragar (o devuelve un veredicto).
2. `detachGroupsAccount` **no** sigue a `clear()` si el borrado falló: la asociación tiene que seguir en pie,
   porque los datos siguen en pie. Ojo con el orden — la sesión en la nube ya se cerró en ese punto, así que
   hay que decidir qué se le ofrece: reintentar el borrado, o rehacer la asociación.
3. Un aviso propio de esta pantalla, del molde del de «No pudimos soltar la cuenta», y su canario.

## Cómo se prueba

Con el seam de UITest que ya existe para el wipe (`-uitest-fail-wipe`, `UITestHooks.shouldFailWipeNow`) o uno
equivalente para este camino; unit del veredicto + XCUITest del aviso.


---

## Paso 0 · el árbol de decisiones, resuelto antes de escribir

**Qué se le ofrece a la persona tras el fallo — la que el ticket dejaba abierta.** Se ofrece **terminar el
borrado**; no se rehace la asociación, y **no se repite el gesto**. Las tres mitades están medidas:

- **Rehacer la asociación no se puede.** Cuando el borrado corre, `CloudAuthService.signOut()` ya soltó las
  credenciales. Ofrecerlo sería pedirle a la persona que vuelva a entrar en la cuenta para poder salir.
- **Repetir el gesto entero es peligroso**, y era el diseño con el que se empezó. Volvería a entrar por
  `pushGroupsForSignOut` **después** del teardown, que es justo lo que prohíben los docblocks de
  `pushAllPendingGroupsForSignOut` y de `attemptGroupsOnlyClose`. Y no es teórico: las filas `Split*` siguen
  vivas y la pestaña Grupos funciona sin sesión, así que un gasto añadido entre el fallo y el reintento deja
  History que el `drainOnce` de ese push traduce a outbox — el pre-check deja de cortar, el loop quema 20
  ciclos contra un backend sin credenciales y el desasociar se vuelve **imposible de terminar**. De paso,
  `writeMirror` repondría en el espejo del App Group los montos que el teardown acababa de purgar.
- **Terminar el borrado sí es seguro y no necesita sesión**: es local, sobre un store con
  `cloudKitDatabase: .none`, y va firmado con el autor del canal. Lo hace `retryDetachPurge`, que hace el
  borrado y su remate y nada más.

**Cómo viaja el fallo: un veredicto de retorno, no un case nuevo en `Phase`.** `Phase` la leen seis sitios
que no tienen nada que ver con este gesto —`RelaunchNetLogic`, `ProfileView.syncSignOutUI`, tres puntos de
`ContentView`, `WelcomeGroupsGateView`— y un case más les cambiaría el comportamiento por defecto a cambio
de nada. `.idle` sigue siendo verdad: el coordinador no está haciendo nada. **La que mentía era la
pantalla**, y es la pantalla la que ahora recibe el veredicto.

**Y la marca de «a medias» es DURABLE, no `@State`.** La fase muere con el proceso y este estado no. Sin
`GroupsDetachPendingPurge`, al reabrir la app la sección volvería a ofrecer el gesto entero con sus dos
salidas y **la segunda ya no puede aplicarse**: el puente está soltado, así que un `.remove` no encuentra
nada que quitar, no quita nada, y el gesto termina diciendo que sí. Quien pidiera quitar sus movimientos del
Panel se los quedaría, sin un aviso.

**Dónde va el seam de prueba: en el escritor.** El `-uitest-fail-wipe` que ya existía **no cubría este
camino** — el desasociar llama a `DataWipeService.deleteLocalGroupsRows`, no a `wipeLocalGroupsDomain`, y el
seam estaba repetido en cada llamador en vez de vivir en el escritor común. Bajarlo cubre los tres caminos
y lo hereda el cuarto que nazca.

## Cerrado en código (2026-09-11)

**Los tres AC del ticket, hechos:**

1. `CloudSessionSignOut.purgeGroupsDomainForDetach` es `throws` y ya no tiene `catch`: el error del
   escritor sale entero. `deleteLocalGroupsRows` hace `rollback()` antes de propagar, así que quien lo
   recibe recibe además un contexto limpio.
2. `detachGroupsAccount` trata el borrado como su **última condición, no su último paso**: si lanza, no
   corre el remate (`finishDetach`: asociación, marker, widget). Arma `GroupsDetachPendingPurge`, emite el
   canario `groupsDetachPurgeFailed` (fuera de `#if DEBUG`, molde de `freshStartWipeFailed`) y devuelve
   `.purgeFailed`.
3. Aviso propio con **Reintentar** y **Más tarde**, y la sección lo recuerda: con la marca puesta el cuerpo
   dice que quedó a medias y el botón pasa a ser **«Terminar de soltar la cuenta»**, sin volver a preguntar
   por el puente. Quien pulsa «Más tarde» y vuelve otro día se entera — el aviso no sobrevive a salir de la
   pantalla, la marca sí.

**Lo que la review adversarial cazó, y era MÍO en su mayoría** (tres lentes + las reglas de área leídas
contra el diff). Los cuatro que cambiaron el diseño:

- **Repetir el gesto entero no era seguro** (arriba). El reintento pasó a ser acotado.
- **La segunda pasada ignoraba en silencio la salida elegida** y reportaba éxito. De ahí la marca durable.
- **El copy mentía por omisión.** Decía «tus grupos siguen aquí, la cuenta sigue asociada», que se lee como
  «no ha cambiado nada» — y para entonces el puente YA se aplicó (con «quitar», las transacciones ya se
  borraron) y la sesión YA está cerrada. El cuerpo lo dice ahora, en los 16 idiomas.
- **`accessibilityIdentifier` no se propaga dentro de un `.alert` de SwiftUI** (medido en el repo el
  2026-09-04). Los que puse eran inútiles y, peor, el control negativo del XCUITest —un
  `XCTAssertFalse(…exists)`— habría pasado SIEMPRE. Retirados; el test navega por posición.

Y tres defectos preexistentes del mismo gesto, arreglados porque son el mismo objeto:

- **`detachBridge` devolvía un `Outcome` vacío cuando su `save()` fallaba**, así que el `guard != nil` del
  llamador lo leía como éxito: el desasociar seguía, borraba las cinco `Split*` y dejaba las transacciones
  apuntando a una zona sin filas vivas — dinero atrapado que no recoge ningún barrido. Ahora devuelve `nil`.
- **El abort por puente ilegible pintaba «quedan cambios sin subir, inténtalo en un momento»**, que
  describe un problema que no es. Tiene motivo propio (`.bridgeUnreadable`) y su copy.
- **`.busy` era mudo**: con un cierre de sesión del Perfil en curso, la persona confirmaba y no pasaba
  absolutamente nada. Es el modo de fallo que el alert de bloqueo existe para cerrar.

**Y un hallazgo de método, que costó tres corridas: los XCUITest de esta suite van con el scheme
`Yala Dev`.** Con `-scheme Yala` la fila «¿Dónde viven tus datos?» **no existe**:
`StorageRowGateLogic.isVisible` exige `remoteEnabled || isEngaged`, y `CloudRemoteConfig.decide` corta en
`isUITestHost` devolviendo `absentDefault`, que sin `DEV_BUILD` es `false` (fail-closed). Los cuatro casos
de la suite fallaban por eso, incluidos los dos preexistentes, con un rojo que parecía del disco.

**Y una segunda review sobre el arreglo de la primera** —lo que se escribe DESPUÉS de una review no lo ha
revisado nadie— que cazó tres cosas más, las dos primeras ALTAS:

- **La marca durable no iba sellada**, así que «Terminar de soltar la cuenta» borraba el dominio Grupos de
  la cuenta asociada EN ESE MOMENTO. Con el fallo puesto, quien pulsara «Entrar» y luego «Terminar» se
  quedaba dentro de una cuenta cuyos datos locales acababa de borrar y cuya asociación acababa de limpiar
  — sin teardown ni `signOut()`, porque el reintento no los hace. Ahora va sellada con el `sub` y el guard
  vive **dentro del coordinador**, no solo en la vista.
- **El boot-wipe del cierre de sesión no se la llevaba.** Nombra a las tres hermanas —el latch, la
  asociación, el libro— y se olvidaba de ella: el siguiente humano veía un botón para terminar de soltar
  una cuenta que nunca asoció. Y el «Empiezo de cero» tampoco, porque esa función es una **lista de keys,
  no un barrido por prefijo** — mi propio docblock afirmaba lo contrario.
- **`.bridgeUnreadable` encendía TAMBIÉN el aviso del Perfil**, hoy, no «algún día»: la fase es un
  singleton observable y esa pantalla está montada debajo. Le hablaba a la persona de cerrar la sesión
  entera cuando solo pidió soltar una cuenta de grupos. Los dos motivos del desasociar ya no presentan
  nada allí.

**Verificado en simulador:** `YalaTests/CloudSync/GroupsDetachPurgeFailureTests` **14/14**, el gate con
**380 tests en 45 suites** y `GroupsAssociationRowUITests` **5/5** con `Yala Dev` (más
`SessionExitsPerCellUITests` 3/3 y `WelcomeFreshStartAlertUITests` 2/2, el otro consumidor del seam que se
movió). **Catorce mutantes verificados a exit 65**: el `catch` tragón (también partido en dos líneas), el
remate por delante del borrado, el canario quitado y el canario mudado al camino de éxito, el `rollback()`
del escritor, el `clear()` incondicional del libro, el `Outcome` vacío del save fallido, la marca sin
armar, el sello que no compara, el reintento sin sus guards, `finishDetach` sin limpiar la marca, el
reintento repitiendo el gesto, y el relevo de humano sin nombrar la marca.

**Criterios de aceptación**

- [x] El borrado propaga en vez de tragarse el error.
- [x] Si el borrado falló, la asociación NO se limpia: asociación y datos cuentan la misma historia.
- [x] Aviso propio en la pantalla + canario de métricas.
- [x] Decidido y documentado qué se ofrece tras el cierre de sesión en la nube (terminar el borrado).
- [x] Seam de UITest que alcanza este camino + unit del veredicto + XCUITest del aviso y su control.

**Lo que el simulador NO alcanza, medido**: el botón «Terminar de soltar la cuenta» y el cuerpo «Quedó a
medias». La marca va sellada con el `sub`, y `-uitest-fake-cloud-session` finge **solo** el predicado de
sesión — su docblock declara que no propaga `currentUserID`, a propósito— así que en el simulador no hay
`sub` y la marca no se arma. Hace falta un seam que siembre la asociación, el mismo que le falta a la
celda «asociada sin sesión viva» desde el paso 10: ticket `uitest-seam-for-a-seeded-groups-association`.
Lo cubren mientras tanto los 14 unit y el device-QA.

**Y falta device-QA, que NO es simulable.** El seam hace lanzar al borrado *antes de tocar nada*, así
que lo que el simulador prueba es el aviso y que la sección sigue en pie. Lo que solo se ve en
device es el recorrido con una sesión de grupos REAL: que tras el fallo la pestaña Grupos siga entera, que
«Terminar de soltar la cuenta» funcione **sin sesión viva**, y que re-asociar después no duplique los
gastos conservados. Recorrido nuevo para `tickets/qa/device-qa-groups-account-association.md`.

**Deja cuatro tickets**: `groups-purge-save-crosses-two-stores-without-atomicity` (el `save()` promete
atomicidad y cruza dos archivos), `uitest-seam-for-a-seeded-groups-association` (medium, desbloquea dos
celdas), `es-ar-storage-groups-block-is-in-tuteo-not-voseo` y
`groups-detach-save-breadcrumb-never-closes-on-throw`.

## QA · 2026-09-16 — cerrado sin verificar: no replicable (override de Jürgen)

- **En un iPhone no se puede provocar.** El desasociar sube lo pendiente y, si algo lo bloquea, sale
  **antes de escribir nada** (`CloudSessionSignOut.swift:240`). El modo avión y el kill-switch se quedan
  ahí, así que nunca llegan al borrado que tendría que fallar (`:285-304`).
- **En simulador tampoco, con lo que hay.** `-uitest-fail-wipe` exige `-uitest`, que monta los stores
  `*-UITest` (`SwiftDataConfiguration.swift:197-203`): no convive con una asociación real. El seam que lo
  haría posible (`-uitest-groups-association`) no existe; su ticket sigue en backlog
  (`uitest-seam-for-a-seeded-groups-association`), y ese ticket ya entrega el XCUITest del botón.
- **Lo que queda de red:** `GroupsDetachPurgeFailureTests` (14 tests) y
  `GroupsAssociationRowUITests.swift:159-161`; commit `d4db3224` en HEAD.
- **Una promesa de arriba que no se cumplió, y no debe cumplirse:** el «recorrido nuevo» para
  `device-qa-groups-account-association` (:176-180) no se añadió, y no se puede ejecutar.

Medido por un lector del barrido sobre `2.1` @ `bebd57a57`.
