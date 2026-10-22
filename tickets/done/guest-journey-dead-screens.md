---
id: guest-journey-dead-screens
status: done
created: 2026-08-12
updated: 2026-09-04
source: YalaWiki/Bugs/grupos-recorrido-del-invitado-codigo-muerto-y-docblock-caducado.md
---


# El recorrido del invitado arrastra tres pantallas inalcanzables y un docblock que miente

## Por qué importa (no es limpieza cosmética)

Es la familia exacta del `AppAttestClient.ensureRegistered()` de `.claude/rules/gateway-attest.md`: **un
docblock cierto cuando se escribió, que hoy invita a archivar como inalcanzable el ÚNICO productor vivo
del recorrido**. Aquella promesa falsa costó una vuelta entera de diagnóstico del 401. Esta está en el
camino de entrada de todos los invitados de Grupos.

## Lo medido

### 1 · El docblock dice DARK y hay dos call-sites de producción

`GroupBackendInviteService.swift:7` afirma: «DARK (G4): sin call-sites de UI — el "compartir enlace"
backend lo cablea G5».

Medido: `createInviteLink` se llama desde **`GroupMembersView.swift:467`** y
**`GroupDetailViewModel.swift:469`**, los dos botones reales de generar el enlace.

### 2 · Tres pantallas del invitado no tienen productor

Grep sobre `Yala/`: `presentGroupInviteOnboarding`, `presentGroupReconnect` y `offerRestoreBeforeInvite`
aparecen **solo** en su declaración (`RouterIntent.swift:106-110`) y en el drain
(`ContentView.swift:908-915`). **Ningún `submit(...)` los produce.** `showGroupReconnect = true` y
`showRestoreOffer = true` tienen exactamente un call-site cada uno: ese drain muerto.

⇒ son inalcanzables:
- `GroupReconnectView` con sus modos (`ReconnectMode` declara **ocho** casos en `RouterIntent.swift:29-47`, en cinco ramas),
- `handleReconnectJoin` (`ContentView.swift:1953-1999`),
- la oferta de restaurar iCloud antes de unirse.

`AppBootstrapper.inviteRouteDecision`, que los decidía, **se declara huérfana en su propio docblock**
(`AppBootstrapper.swift:2051-2055`) y el grep lo confirma. El único camino vivo al onboarding del invitado
es `.presentGroupBackendInviteOnboarding`; el otro está bajo `#if DEBUG`.

### 3 · Tres residuos del canal borrado, todos dentro de este recorrido

1. **`welcome.invite.back`** = «Volver» — existe en los 16 locales. El botón real de `InviteRecoveryView`
   es `L10n.Action.back` = «Atrás».
   > ⚠️ **Corrección de la primera pasada**: se declaró «copy muerto, medido con grep» y **es FALSO**.
   > La usa `Yala/App/Views/Onboarding/WelcomeBackButton.swift:29` como `accessibilityLabel`. Es copy
   > **vivo** — invisible, pero vivo para VoiceOver. Queda escrito como recordatorio de que un grep de
   > una key no ve los `accessibilityLabel`.
2. **`ContentView.swift:2042-2043`** conserva `if GroupInviteOnboardingLogic.shouldClearPendingInvite(outcome:) { }`
   con el **cuerpo vacío** — el `PendingInviteStore` que limpiaba ya no existe.
3. **La fase `.accepting` del tracker no la escribe ningún camino de release**: `noteAcceptStarted` no
   tiene NINGÚN call-site en `Yala/` fuera de su declaración; sus dos emisores eran del transporte y
   queda el hook `#if DEBUG` `_uitestForcePhase` (`:143-156`). Su `retry()` la degrada a `.expired` ⇒ la
   rama del banner con «Reintentar» —`acceptFailed(recoverable: true)`— es **inalcanzable**.

### 4 · El trigger `.remoteInsert` del reconciliador no tiene call-site

`GroupJoinReconciler.Trigger` declara cuatro casos (`:27-29`) y `mapTrigger` los mapea todos, pero los
vivos son exactamente `.boot` (`AppBootstrapper.swift:487`), `.foreground` (`ContentView.swift:498` y
`:1314`) y `.acceptShare` (`GroupInviteOnboardingView.swift:177`, `GroupJoinIntentTracker.swift:124`).

⇒ entre que el pull materializa el grupo y el siguiente foreground o arranque, **nadie reconcilia el
intent**. Coherente con lo que ya dice `.claude/rules/swiftdata-cloudkit.md` («sus triggers vivos son boot
/ foreground / acceptShare»), pero el enum sigue prometiendo cuatro.

## El fix

Para cada pieza, **decidir entre cablear o borrar** — y escribirlo. Lo que no vale es dejarla declarada:

| Pieza | Cablear tendría sentido si… | Si no, borrar |
|---|---|---|
| `GroupReconnectView` + 8 modos | se quiere recuperar el flujo de reconexión | es la más cara de mantener viva sin uso |
| `offerRestoreBeforeInvite` | el invitado con datos previos merece la oferta | — |
| `.remoteInsert` | se quiere reconciliar sin esperar al foreground | quitar el caso del enum |
| `.accepting` + `retry()` | vuelve a haber transporte que la emita | quitar la rama del banner |
| `if { }` vacío de ContentView | — | borrar |

**Y el docblock de `GroupBackendInviteService` se corrige en el mismo movimiento**, porque es el que
puede hacer que alguien borre lo vivo.

## Criterio de hecho

- Cero intents declarados sin `submit`. Un source-scan lo pinnea barato y evita la reincidencia.
- El docblock de cada servicio de Grupos que declare DARK, con su grep de call-sites al lado o sin la
  palabra DARK.

## Relacionados

- [[grupos-enlace-de-invitacion-cinco-causas-un-solo-mensaje]]
- [[grupos-invitado-el-no-no-tiene-pantalla]]

## Re-medición (2026-08-12, sesión de ataque)

Todo lo del ticket **se confirma** contra el árbol. Los tres intents siguen sin productor:

```
$ grep -rn "submit(.presentGroupInviteOnboarding|submit(.presentGroupReconnect|submit(.offerRestoreBeforeInvite" Yala/
(sin resultados)
$ grep -rn "showRestoreOffer = true" Yala/
Yala/App/ContentView.swift:921        ← el drain muerto, único call-site
```

### Hallazgo 1 · el alert de «oferta de restaurar» también es inalcanzable, y no estaba en el ticket

`showRestoreOffer` tiene **un solo** sitio que lo pone a `true`: el drain de `.offerRestoreBeforeInvite`.
⇒ el alert entero de `ShellDataAlertsModifier` (`Welcome.OfferRestore.*`, tres botones, un
`wipeAllUserData` + `wipeLocalGroupsDomain`, y su copy en 16 locales) **es código muerto**.

**Importa para el ticket hermano**: el commit `73ab6134` (el de «empiezo de cero») le añadió a ese
alert un canario y el corte de navegación, porque comparte el defecto del `catch` mudo. No es daño
—es código muerto que ahora fallaría mejor— pero si se borra, el conteo de
`FreshStartWipeAlertTests.wipeFailure_emitsCanaryInBothWipingAlerts` baja de 2 a 1 y **ese test
obliga a decidirlo**, que es justo para lo que se le puso el conteo.

### Hallazgo 2 · el docblock de `GroupBackendInviteService` sigue mintiendo (y es la pieza peligrosa)

`Yala/Services/CloudSync/Groups/GroupBackendInviteService.swift:7` sigue diciendo «DARK (G4): sin
call-sites de UI — el "compartir enlace" backend lo cablea G5», y `createInviteLink` se llama desde
`GroupMembersView.swift:467` y `GroupDetailViewModel.swift:469`. **Es la familia exacta del
`AppAttestClient.ensureRegistered()`**, y por eso el ticket la pone primero: un docblock que invita a
archivar como inalcanzable el único productor vivo del recorrido.

> ⚠️ Nota de coordenada: el fichero está en `Yala/Services/CloudSync/Groups/`, no en
> `Yala/Services/Groups/`.

## Por qué no se ejecutó el borrado

Decisión del owner: borrar lo inalcanzable (`GroupReconnectView` + 8 modos, `handleReconnectJoin`,
`offerRestoreBeforeInvite`, el `if {}` vacío, `.remoteInsert`, `.accepting`) y cablear `branded`.

El alcance real medido son **~10 ficheros** —`RouterIntent` (3 casos + `ReconnectMode` + sus 4
apariciones en las tablas de prioridad/serialización), `ContentView` (drain, 2 `@State`, 2 bindings,
`handleReconnectJoin`, el `.sheet`, el alert de OfferRestore), `ContentViewReadinessLogic`,
`ReadinessGateObservers` (los dos con su campo de la matriz), `GroupReconnectView` entero,
`AppBootstrapper.inviteRouteDecision`, `GroupJoinReconciler`, `GroupJoinIntentTracker`, más las keys
de l10n de los dos copys que mueren— y toca **la matriz de readiness**, que es donde vive el bug de la
«toolbar muerta» del 2.0.5.

Con la noche ya avanzada preferí no abrir un borrado de ese tamaño a medias sobre `ContentView.swift`,
que en esta sesión ya lo tocaron tres commits. **Es lo primero que recomiendo retomar**: está decidido,
medido, y no depende de nadie.

**Y si solo se hace una cosa de este ticket, que sea el docblock**: es la pieza que puede hacer que
alguien borre lo vivo, y cuesta dos líneas.

migrated from YalaWiki Bugs/grupos-recorrido-del-invitado-codigo-muerto-y-docblock-caducado.md @ 1934e8ad

---

## CERRADO · 2026-09-04 — el borrado se ejecutó, y el mapa del ticket estaba mal en tres puntos

Cerrado con sus dos criterios de hecho cumplidos y verificados. El borrado va en `4f01484e`
(−821/+69, 41 ficheros); el pin del criterio, en el commit de cierre.

### Antes de borrar: cada pieza pasó por dos lentes que intentaban probar que seguía VIVA

No se ejecutó el mapa de este ticket tal cual, y menos mal. De las siete piezas que daba por
muertas, **tres no lo estaban**:

1. **El copy `groups.reconnect.*` está VIVO** y se queda entero en los 16 locales.
   `deletedForAll.body` la consume producción por la **key cruda** en
   `GroupBackendInviteEntryHandler` (`String(localized:)`), invisible a cualquier grep del accessor
   `L10n.Groups.Reconnect`. Es la trampa que este mismo ticket documenta para `welcome.invite.back`
   — la misma familia, la otra cara: allí el grep de la key no vio un `accessibilityLabel`, aquí el
   grep del accessor no habría visto la key cruda. Además, los cuerpos `rejectedRetry`, `leftRetry`
   y `removedRetry` son el único texto traducido que explica los casos del bug abierto el mismo día
   (`rejected-member-cold-tap-does-nothing`), que los va a reusar.
2. **`ReconnectMode` e `inviteRouteDecision` estaban vivos en tests**: 23 `@Test` de
   `AppBootstrapperTests` eran su única especificación ejecutable. Se retiraron a conciencia, con
   el borrado, no de paso.
3. **`InviteMetadata` se queda**: la consume `GroupInviteOnboardingView`, viva, y es el tipo que
   `invite-link-five-causes-one-message` quiere repoblar al cablear `branded`. Borrarla habría sido
   trabajo que se deshace en dos semanas. **`branded` NO se cableó aquí**: su medición a fondo vive
   en ese ticket, y duplicarla era la forma segura de divergir.

### Dos piezas de este ticket YA estaban hechas y él no lo sabía

Llevaba 23 días pidiendo trabajo hecho, y encima el que declara prioritario: el docblock de
`GroupBackendInviteService` se corrigió el 2026-08-12 en `cd87cf3a` —el mismo día en que la
re-medición de este ticket afirmaba que «SIGUE mintiendo»— y el `if {}` vacío de
`shouldClearPendingInvite` ya no existía (grep con control positivo: cero coincidencias).

### La poda NO se apoya en que los casos estén cubiertos

Se verificaron las dos hipótesis del re-join que pedía `groups-reconnect-prune-or-rewire`, y
salieron **PARCIALES**: apareció un caso real sin salida —el rechazado que tapea un enlace con la
app cerrada—. **Ninguna pantalla lo habría rescatado**: muere aguas arriba, en `enterBackendInvite`
y en `decideBackend`, antes de cualquier presentación. Por eso la poda es correcta y la
justificación honesta es «esta maquinaria no tiene emisor», no «los casos están cubiertos». El
hueco salió en su propio ticket, con prioridad alta.

⇒ Con esto, `groups-reconnect-prune-or-rewire` queda **resuelto por la opción (a)**, podar, y
debería cerrarse o descartarse: su pregunta ya no está abierta.

### Criterio de hecho 1 · «cero intents declarados sin `submit`»

`YalaTests/RouterIntentEmitterCoverageTests.swift`. Hoy: **28 cases, 0 huérfanos**.

El pin hace falta porque **el compilador obliga a MANEJAR un case nuevo, no a EMITIRLO** — los
switches exhaustivos de `RouterIntent` cazan lo primero y son ciegos a lo segundo. Ése es
exactamente el hueco por el que tres intents sobrevivieron un mes a la muerte de su productor.

### Criterio de hecho 2 · «ningún docblock DARK sin su grep al lado»

El segundo escáner del mismo fichero. **Al escribirlo cazó un tercer caso que nadie había
medido**: `InviteLinkService.buildBackendInviteURL` declaraba «DARK: sin call-sites de UI hoy» y
tiene **cuatro** call-sites de producción — es el productor del enlace de invitación de todos los
grupos backend. Corregido con su grep al lado, como manda el criterio.

El escáner distingue la promesa **afirmada** de la **citada o narrada en pasado**, porque este
repo documenta sus propios errores («este docblock decía…») y esa prosa es justo la que queremos
que se escriba. Es una heurística por marcadores, y está dicho en el propio test: si algún día deja
de sostenerse, se afina la lista, no se borra el escáner.

### Los dos escáneres están verificados por MUTACIÓN, no por su verde

Un pin que nunca se ha visto fallar no es un pin. Se les inyectó cada defecto y los cazaron:
retirar el único emisor de `.iCloudMismatch` → `huerfanos → ["iCloudMismatch"]`; añadir «DARK: sin
call-sites de UI hoy» a `GroupJoinReconciler` → `infractores → ["GroupJoinReconciler.swift"]`.
Ambos mutantes revertidos.

### Aviso para el futuro

Las coordenadas de este ticket estaban caducadas —9 de 13, y dos rutas mal escritas— y su alcance
de «~10 ficheros» se quedó corto: fueron 41, porque omitía el único consumidor vivo que quedaba
(`YalaTests/AppBootstrapperTests.swift`, 23 pruebas). Al retomar cualquier ticket de esta zona:
greppea, no abras la línea citada.
