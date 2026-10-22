# Mitad 2: groups-entry-on-a-mirrored-store-still-blocks-the-owner (consume verbo paso 9)

## Contexto
Jürgen 2026-09-11: lanzar ahora en bypass. El **paso 9** (`session-exits-one-verb-per-session`, PR #138) ya está en `2.1` — el verbo que esta puerta necesitaba (espera export demostrable → borra local → iCloud intacto → neutro) **ya existe**.

Hubo una sesión previa (2026-09-10) que midió, construyó un borrado propio estrecho, falló review adversarial, y dejó código en rama `encargo/2026-09-10-…` **sin PR** (decisión: esperar al paso 9). **No reutilices ese worktree.** Parte de `origin/2.1` limpio. Lee la medición del ticket (objeciones swap/wipe, sección «Lo que deja el paso 9») y consume el verbo nuevo — no reinventes el wipe del sign-out.

Objetivo producto: «Vengo por un grupo» con store que ya lleva espejo **nunca bloquea** al dueño; vuelve al neutro y sigue al sign-in; iCloud del corpus intacto; retira la puerta «datos ajenos» cuando sea seguro.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear`. Ambigüedad NUEVA: elige lo más seguro alineado con ADR §2-3 + ticket y regístralo. Device-QA CloudKit → `tickets/qa/`.

Avisos a Frank: (1) bloqueo acceso; (2) PR; (3) `/cerrar-total` resumen; (4) idle — una vez.

## Que se pide
1. Leer ticket entero (sobre todo «Lo que deja el paso 9») + ADR §2-3 + APIs del verbo de salida del paso 9.
2. Implementar la vuelta al neutro consumiendo ese verbo; retirar/reescribir la puerta «datos ajenos».
3. Un PR a `2.1` + `/cerrar-total`.

## Que NO hay que tocar
marketing/. Paso 10 del runbook salvo lo mínimo. Reabrir el worktree/rama del 10-sep. Wipe que exporte deletes a iCloud.

## Como se sabe que esta bien
Criterios del ticket; dueño no queda atrapado; iCloud intacto; PR mergeado; board/`TICKETS.md` al día; `/cerrar-total`.

---

## Paso 0 — el árbol de decisiones, resuelto contra el árbol (2026-09-11)

Medido en `d723f1f4` (= `origin/2.1` + un commit de docs). Todas las coordenadas son de ESTE árbol.

### Lo primero: las tres razones del bloqueo, re-medidas una por una

El ticket quedó `blocked` por una conjunción, y la lección de la sesión del 10-sep es que refutar UNA no
reabre el camino. Las tres, contra el árbol de hoy:

| Razón del bloqueo (10-sep) | Estado hoy | Medido en |
|---|---|---|
| 1 · «esperar al export no existe en el repo» | **REFUTADA.** `PrivateSignOutExportGateLogic` + `PersonalExportPendingCounter`, con ancla monótona en `iCloudSyncService.confirmedExportStart` | `Yala/App/Logic/PrivateSignOutExportGateLogic.swift` · `Yala/Services/CloudSync/PersonalExportPendingCounter.swift` |
| 2 · «el boot-wipe no es reusable: no cumplo sus precondiciones» | **REFUTADA, pero solo si se consume el COORDINADOR entero.** Sus tres precondiciones («el coordinador ya subió el outbox, cerró la sesión y armó») las cumple `CloudSessionSignOut`, no un `armSignOutWipe()` suelto | `SwiftDataConfiguration.swift:622-625` (docblock) · `CloudSessionSignOut.swift:339-368` |
| 3 · «el arm no tiene desarme si el borrado aborta» | **REFUTADA en `.icloud`**, que es esta celda: el abort desarma | `SwiftDataConfiguration.swift:695-701` |

⇒ el camino se reabre **solo por la puerta del coordinador**. Lo que sigue bloqueado —y no se toca— es
llamar a `armSignOutWipe()` a mano desde la puerta, que es lo que la review del 10-sep tumbó.

### D1 · ¿Qué verbo se consume? → **`CloudSessionSignOut.signOut(context:confirmedPath:confirmedWithoutICloudCopy:)`, sin API nueva**

`finalizeSessionExit` es `private` (`CloudSessionSignOut.swift:339`) y `ExportPolicy` también
(`:142-150`), así que el tramo que el ticket nombra no es alcanzable desde fuera. **No hace falta
exponerlo:** el portal público ya enruta a él, y en esta celda enruta bien. Calculado a mano sobre el
cuerpo literal de `CloudSignOutFlowLogic.path` (`:71-81`) con el estado B —`storageMode == .icloud`,
sin sesión secundaria, `hasLiveSession == false`, capacidad de grupos compilada, `hasPrivateSession ==
true` porque `isGroupInviteMode` es `false` en el Welcome—:

```
.privateSignOut  →  exitPlan  →  ExitPlan(kind: .privateOnly, waitsForExport: true)
```

Y con `.privateOnly` (`pushesGroups == false`) el tramo hace exactamente lo que esta puerta necesita y
**nada de lo que la review del 10-sep le reprochaba**:

- **no** sube grupos y **no** borra el store de Grupos: `forgetsGroups = kind.pushesGroups || hasBackendGroupRows(context:)`
  (`CloudSessionSignOut.swift:405`) ⇒ con `.privateOnly` y sin filas del canal backend, el marker
  `includesGroups` no se pone y `YalaGroups` sobrevive;
- **bloquea en vez de descartar** si quedara outbox de grupos (`blockIfGroupsCannotUpload`, `:280-292`);
- espera al export y solo entonces arma.

Añadir un método público propio se descarta: duplicaría el dispatch y crearía una segunda verdad sobre
qué celda es ésta. El `confirmedPath: .privateSignOut` es el cinturón que ya existe para eso (`:105-108`).

### D2 · ¿Se acepta el RELANZAMIENTO? → **SÍ, y no es una decisión nueva**

El ticket lo dejaba «pendiente de Jürgen». Está contestado por escrito en dos sitios, los dos anteriores
a esta sesión:

- la **matriz del ADR**, fila **B · Vengo por un grupo**: «**sin bloqueo**: vuelta al neutro (borra local,
  iCloud intacto, **relanza**) y sigue» (`docs/sessions/2026-09-09-matriz-escenarios-sesiones.md:50`);
- el **encargo de hoy**: «el verbo que esta puerta necesitaba ya existe … **consume el verbo nuevo**»,
  sabiendo que ese verbo relanza (lo dice la sección del propio ticket que manda leer).

La alternativa —ensanchar `PersonalSwapReleaseLogic.mountAdmitsSwap` a mounts CON espejo— sigue cerrada
por la medición en device del spike R3 (CloudKit emitió 5 eventos en los 10 s POSTERIORES al release), y
el encargo no la pide. **Se acepta el relanzamiento y se registra aquí.**

### D3 · ¿Cuál es el DISPARADOR de la vuelta al neutro? → **el eje ANCHO, no `.iCloudMirror`**

`PersonalStoreDecision.attachesCloudKitMirror` (`SwiftDataConfiguration.swift:410-419`) es `true` tanto
para `.iCloudMirror` como para `.localNoMirror` —medido: `.automatic` adjunta el espejo aunque no haya
cuenta— y `false` para `.neutralNoMirror`, que es el mount de toda instalación fresca. O sea que el eje
ancho contesta exactamente la pregunta de esta puerta: **«¿este arranque puede exportar a iCloud lo que
escriba el recién llegado?»**. Es el uso que la rule de área declara correcto («sirve donde la pregunta
es sobre el espejo que YA está puesto», `.claude/rules/swiftdata-cloudkit.md:199`).

Dos términos, en OR:

- `hasExistingData` — hay corpus que borrar;
- `mountAttachesMirror` — aunque el store esté vacío: dejar pasar con el espejo puesto mandaría los
  gastos de grupo del recién llegado al iCloud del dueño del teléfono.

### D4 · ¿`restoreInProgress` sigue decidiendo? → **NO, y sale de la firma**

Hoy es el término que impide bloquear a la dueña que está restaurando (`GroupsOrganizerGateLogic.swift:114`).
Con la vuelta al neutro deja de haber veredicto que corregir: restaurando o no, la respuesta es la misma
—volver al neutro— y el criterio de aceptación nº 3 lo pide explícitamente («la señal de restore se
cancela, vuelta al neutro»). Se retira del parámetro y la cancelación (`ICloudRestoreSessionSignal.noteRestoreFinished()`)
pasa a ser un efecto del ejecutor, no un término de la tabla.

### D5 · ¿Se PREGUNTA antes de borrar? → **se informa; se pregunta solo sin prueba de copia**

Decisión de Jürgen en el ticket padre: «se avisa, pero no se pide confirmación … **informar, no
preguntar**». Su premisa explícita es que «sus datos personales siguen a salvo en iCloud», y esa promesa
solo es cierta si hay copia. ⇒ se reusa el canal que el paso 9 ya construyó
(`CloudSessionSignOut.privateCopyChannel()`, `:161-165`):

- `.iCloud` → **informa y sigue**, sin confirmación;
- `.none` → **segundo gesto**, y solo se llega ahí **con prueba** (`mirrorReportedNotAuthenticated`), que
  es el hallazgo nº 7 de la review del paso 9 («"no hay copia" solo con prueba»).

El segundo gesto viaja como `confirmedWithoutICloudCopy: true`, que es lo que hace `waitsForExport: false`.
**Ambigüedad nueva, resuelta por lo más seguro y registrada aquí.**

### D6 · ¿Quién pinta el terminal «reabre Yala»? → **el del cierre de sesión, y el Welcome se cierra**

Medido: `WelcomeFlowModifier` (`ContentView.swift:337`) y `SignOutRelaunchNetModifier` (`:357`) están
ENCADENADOS sobre el mismo body ⇒ un solo host, y UIKit presenta uno. El terminal del sign-out se arma
con `phase == .awaitingRelaunch`, tiene verify loop con prueba de presentación efectiva, blocker de
readiness y auto-salida en segundo plano, todo device-validado. ⇒ **el step del Welcome se cierra al ver
`.awaitingRelaunch`** y deja presentar al terminal que ya existe; su verify loop está escrito justo para
el caso «la presentación anterior aún se está cerrando».

Lo que se pierde —el terminal del Welcome dice «seguimos justo donde lo dejaste» y el del sign-out no—
se compensa **antes**: la pantalla de espera de la puerta es la que informa de que lo personal sigue en
iCloud, que es lo que Jürgen pidió comunicar.

### D7 · ¿Se retoma «Vengo por un grupo» tras el arranque? → **SÍ, con el destino durable que ya existe**

Medido: `welcome.pendingMirrorRelaunchDestination` **sobrevive al boot-wipe** — no está en el barrido de
`DataWipeService.removeUserPreferenceKeys` y nadie llama a `clear()` en producción. Y `.groupsOrganizer`
ya es un caso de `WelcomeMirrorRelaunchLogic.Destination` (`:54`). Lo único que falta es su rama en el
consumidor: hoy cae en el `default` de «inalcanzables» y aterriza en el chooser (`ContentView.swift:1546-1556`).

Se retoma **en la PUERTA** (`welcomeFlowInitialStep = .groupsGate`) y no en el alta: el comentario de ese
switch pide no «retomar una rama organizador a mitad en un proceso que no ha visto su puerta», y volver a
la puerta la re-evalúa en un proceso donde ya no hay ni corpus ni espejo ⇒ abre y sigue. Eso cierra
además el «el intent del organizador no es durable» que la matriz anota en la fila A.

### D8 · La entrada por INVITACIÓN → **queda fuera, con ticket propio y por una razón medida**

El ticket la pide («la misma regla para la entrada por invitación») y el criterio nº 2 la nombra. Medido
el camino entero, **cubrirla aquí exige construir dos piezas que ni este ticket ni el paso 9 dejan
hechas**, y las dos son infraestructura, no cableado:

1. **No hay punto de interposición con una persona delante.** Las dos entradas —el universal link
   (`AppBootstrapper.handleInviteLink:2099`) y la card «Tengo una invitación» (que empalma en el mismo
   método por `ContentView:622`)— convergen en `GroupBackendInviteEntryHandler.drive` (`:279`), y ése
   **también lo llama el reconciler en el trigger `.boot`** (`GroupJoinReconciler.swift:182`). Interponer
   ahí la vuelta al neutro sería borrar el corpus de alguien **en el arranque y sin pantalla**, que es
   justo lo que el ADR prohíbe. Hacerlo con pantalla pide un `RouterIntent` nuevo que atraviese la matriz
   de readiness (regla 3 de Presentaciones).
2. **El intent de la invitación NO sobrevive al borrado.** `PendingJoinStore` guarda una sola key,
   `"yala.groups.pendingJoins"`, que el barrido de `DataWipeService.removeUserPreferenceKeys` **no toca**
   —comprobado— pero que muere igual por la cadena `resetForSignOutWipe → resetAllUserPreferences →
   AppRouter.resetAll → PendingJoinStore.clearAll()` (`AppRouter.swift:156`). Sin una superficie durable
   nueva, el invitado reabre la app **sin su invitación**, que es el camino muerto que este ticket existe
   para cerrar.

**Y lo que sí está medido a favor de aplazarla:** la rama de invitación **no tiene hoy ningún término de
corpus** —ni `GroupsGateLogic.nextStep`, ni `GroupBackendInviteEntryLogic.nextStep`, ni
`InviteRecoveryView`— así que **nunca ha bloqueado a nadie**. El síntoma del título no la toca. Lo que sí
la toca es la otra mitad (entrar a Grupos con el espejo puesto), que es **preexistente y este PR no la
agrava**. Sale en ticket propio, `high`.

De camino se mide un segundo defecto, también con ticket: `WelcomeMirrorRelaunchLogic.requiresMirror`
devuelve `true` para `.inviteRecovery` con un sesgo declarado en su docblock («su destino es usar la app
con datos personales»), premisa que el paso 5 del rediseño invalidó — un invitado solo-grupos ya no crea
corpus personal. Hoy eso le cobra un relanzamiento **para adjuntar un espejo que su camino no usa**, y
además lo deja entrando a Grupos con ese espejo puesto.

### D9 · Alcance de lo que NO se toca

- `CrossAccountEntryGuardLogic.blockedForeignData` y la pantalla `welcome_cloud_blocked_foreign_data` del
  sign-in de nube: **son otro enum y otra puerta**, y el ticket solo pide retirar la de Grupos.
- Los términos `channelOff` y `secondarySession` de la puerta: siguen hasta que M1 se retire (paso 12).
- El copy `welcome.cloud.blocked*`: lo sigue usando el sign-in de nube. Se retiran solo las dos claves
  propias de la puerta de Grupos (`welcome.groups.existingData*`).
