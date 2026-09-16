---
id: groups-deleted-group-detail-stays-open
status: done
priority: high
area: groups
created: 2026-08-28
updated: 2026-09-16
qa-status: passed
qa-date: 2026-09-16
qa-notes: PASS en sim 2026-09-16. Entrada por deeplink o notificacion no vista (seam seeded-first abre la lista); por codigo converge en el mismo destino
---

# Tras borrar el grupo, el detalle se queda abierto como si el grupo siguiera existiendo

> [!success] Resuelto (2026-09-05) — rama `encargo/2026-09-05-groups-deleted-group-detail-stays-open`
> **La pregunta que este ticket dejaba abierta ya está zanjada, y por medición, no por lectura del
> cableado: es la hipótesis 1.** Reproducido en el simulador con el código pre-fix: al confirmar el
> borrado, la sheet de Ajustes **sí** se cierra y lo que queda delante es el **detalle en push**, con
> el título del grupo, sus gastos y su FAB. La hipótesis 2 (que lo que quedara fuese Ajustes) queda
> descartada, y la 3 (que el `dismiss()` no llegara a correr) también: corrió y cerró su sheet.
>
> **El hueco.** `GroupDetailDismissDecision.shouldDismiss` decidía el auto-cierre con cuatro señales
> y el soft-delete no enciende ninguna: `GroupService.softDelete` no borra la fila, pone
> `isHiddenForAll`. `isHiddenForAll` pasa a ser el quinto parámetro de esa decisión.
>
> **Las otras dos salidas destructivas de la sheet ya cerraban** — medido, y por eso el fallo era solo
> del borrado: archivar enciende `isArchived` (rama existente) y salir del grupo pasa por
> `performLocalCleanupAndDelete`, que sí hace `context.delete` y enciende `isDeleted`.


## Reporte del owner (device, 2026-08-28, Lima)

TestFlight **2.1 build 12**, teléfono **A** (personal, y en ese grupo el owner).

1. El botón de **borrar el grupo SÍ apareció** esta vez. (El fallo de la corrida anterior —no había
   botón de borrar, y salir del grupo en el teléfono B fallaba con «GroupsRPCError 10»— **no se
   reprodujo en A**.)
2. Tras borrar el grupo, **el detalle del grupo se quedó abierto**, como si el grupo siguiera
   existiendo.
3. El owner tuvo que tocar **Atrás**; después la lista de Grupos **ya no** mostraba ese grupo.

Eso es TODO lo que hay del device. **No** se anotó: si la sheet de Ajustes se cerró o no al confirmar,
qué título tenía la pantalla que quedó delante, si salió algún alert, cuánto tiempo pasó entre el tap y
el «Atrás», ni cuántos gastos/miembros tenía el grupo. **No se inventa nada por encima de esto, y este
ticket no declara la causa.**

## Qué ve el usuario

Confirma dos veces un borrado que la app le presenta como irreversible, y se queda **delante del mismo
grupo**: mismo título, mismos gastos, misma pantalla. Nada le dice que el borrado ocurrió. La única
forma que tuvo de comprobar que sí había funcionado fue salir a mano y mirar la lista. Entre el tap y
ese «Atrás», el usuario tiene motivos para creer que la app no le hizo caso — y el borrado de un grupo
es justo la acción en la que reintentar da más miedo.

## Medido en el árbol — y qué NO prueba

Todo lo de esta sección está medido sobre `2.1` @ `2175e53e`. Si al retomarlo el árbol ya no es ese
commit, re-medir antes de obedecer las coordenadas: es un grep, y en este repo la documentación
envejece más rápido que el código.

Precisión útil, medida en este pase: entre `f4cf3d2b` —el HEAD que `docs/ESTADO.md` (actualizado
2026-08-22) registra como TF build 12— y `2175e53e` hay **23 commits** y **cero** cambios bajo `Yala/`.
Es decir: para el código de esta sección, el árbol de hoy y el binario del device coinciden. Lo que
sigue apoyado en ESTADO.md es la equivalencia «build 12 = `f4cf3d2b`», que se lee del doc y no se
verificó contra el binario.

**Nada de esta sección prueba qué pasó en ESTA corrida.** Es el mapa del terreno, no el veredicto: no
hay traza ni log del device.

### El camino del borrado, tal como está escrito

- `GroupSettingsView.performSoftDelete` (`Yala/App/Views/Groups/GroupSettingsView.swift:582-595`)
  llama a `GroupService.shared.softDelete(group)` (`:588`) y, **en éxito**, hace `DS.Haptic.warning()`
  (`:589`) y **`dismiss()`** (`:590`). Ese `dismiss()` está **medido en el árbol**; que haya corrido en
  esta corrida **no está probado** — no hay traza del device.
- El camino de error es otro: `:591-594` guarda `error.localizedDescription` y levanta el alert de
  `:155-159`. El owner no reportó ningún alert, pero **tampoco se le preguntó**.
- El éxito **no publica ninguna confirmación**: en `:582-595` no hay toast, alert ni copy de `L10n`.
  La única señal es la háptica de `:589`.
- Se llega ahí desde el `confirmationDialog` de `:160-171` (segunda confirmación), gatillado por la
  sección `deleteGroupSection` (`:542-580`), que la pantalla muestra solo si `group.isOwner`
  (`:89-90`) y deshabilita con deuda pendiente (`:568`, hint en `:570-577`).

### Quién es quién en la pila de pantallas

- `GroupSettingsView` se monta como **contenido de una sheet** del detalle:
  `.sheet(item: $viewModel.activeSheet)` en `Yala/App/Views/Groups/GroupDetailView.swift:187-197`, caso
  `.settings` en `:263-264`. El propio fichero se describe como «Sheet de ajustes del grupo»
  (`GroupSettingsView.swift:5`) y su botón de cerrar (`:110-112`) usa el mismo `dismiss()`.
- El **detalle** no es una sheet: es un push —
  `.navigationDestination(item: $viewModel.selectedGroup)` en
  `Yala/App/Views/Groups/GroupsContainerView.swift:176-178`.
- El «Atrás» que tocó el owner es el chevron de `GroupDetailView.swift:140-144` (que llama al
  `dismiss()` **del push**) o el swipe-back de `:137`.

Por la semántica documentada de `@Environment(\.dismiss)`, el `dismiss()` de `GroupSettingsView`
resuelve contra **su** presentación (la sheet), no contra el push del detalle. Eso describe el
cableado; **no dice qué se vio en el device**: no se sabe si la sheet se cerró.

### Qué escribe el borrado, y qué mira el auto-cierre del detalle

- `GroupService.softDelete` (`Yala/Services/Groups/GroupService.swift:226-285`) pone
  `group.isHiddenForAll = true` (`:246`), guarda (`:249`) y bumpea
  `SessionState.shared.incrementDataVersion()` (`:254`). **No borra la fila del store**: es un flag
  (`Yala/Models/SplitGroup.swift:29`, «soft-delete invisible para todos»).
- El detalle **sí** tiene auto-cierre, y corre justo con ese bump:
  `GroupDetailView.onChange(of: sessionState.dataVersion)` (`:239-255`) pregunta a
  `GroupDetailDismissDecision.shouldDismiss(contextIsNil:isDeleted:isArchived:wasArchivedOnAppear:)`
  (`Yala/App/Logic/GroupDetailDismissDecision.swift:24-33`): cierra si el contexto es `nil` o si
  `isDeleted`, o si el grupo **se archivó** durante la sesión. `isHiddenForAll` **no** es ninguno de
  sus cuatro argumentos.
- `SplitGroup` **no declara** un `isDeleted` propio (medido: cero ocurrencias en
  `Yala/Models/SplitGroup.swift`), así que ese `isDeleted` es el de SwiftData — fila borrada del store —
  y el soft-delete no borra la fila. **Inferido de ahí, no medido en runtime**: con solo el flag
  puesto, los cuatro argumentos caerían en la rama «no cerrar» (`:32`).
- Nadie más en esa pantalla lee el flag: `isHiddenForAll` tiene **cero** ocurrencias en
  `GroupDetailView.swift`, `GroupSettingsView.swift` y `GroupDetailViewModel.swift`. Medido por grep:
  en `Yala/App/Views/Groups/` y `Yala/App/ViewModels/` solo aparece en `GroupsViewModel.swift` (×3) y
  `BridgeDeactivationSheet.swift` (×1).

### Por qué la lista sí lo ocultó al volver

`GroupsViewModel` filtra `!$0.isHiddenForAll` tanto en activos (`:78`) como en archivados (`:82`), y el
pop del detalle recarga la lista (`GroupsContainerView.swift:179-183`,
`if newValue == nil { viewModel.loadData() }`). Es decir: **la parte que el owner vio bien (la lista) y
la que vio mal (el detalle) deciden con criterios distintos** — la lista mira el flag del soft-delete y
el auto-cierre del detalle no lo recibe. Medido; no se declara que sea la causa de esta corrida.

### Cobertura del caso, hoy

- `YalaTests/GroupDetailDismissDecisionTests.swift` fija los cuatro argumentos existentes (6 tests, uno
  por combinación relevante). **Ninguno** cubre el soft-delete, porque la función no lo recibe.
- Medido con matching de globs contra `qa/coverage-index.json`: `GroupDetailDismissDecision.swift` **no
  cae bajo ningún `codeGlobs`** del índice. Los dos ficheros de pantalla y `GroupService.swift` sí, vía
  `groups-crud-balances-settlements` (`deterministic`, `xcuitest:YalaUITests/GroupsSmokeUITests` +
  unit, `lastVerified` 2026-08-18).

## Hipótesis vivas (ninguna probada — no cerrar ninguna sin medir)

1. La sheet de Ajustes **sí** se cerró y lo que quedó delante era el **detalle en push**, que no se
   auto-cerró.
2. La sheet **no** se cerró, y lo que el owner llamó «el detalle» era Ajustes encima del detalle.
3. El `dismiss()` no llegó a correr (p. ej. el guard `isDeleting` de `:583`, o un fallo antes de
   `:590`). Contra esto: el camino de error levanta alert (`:591-594`) y no se reportó ninguno — pero
   tampoco se preguntó.

**El reporte no distingue 1 de 2**, y esa distinción es exactamente la que decide dónde va el fix. Por
eso este ticket **no** elige entre «el `dismiss()` no surtió efecto» y «el detalle no se sacó de la
pila»: hoy no hay dato que separe las dos.

## Qué medir la próxima vez (barato, y antes de tocar código)

- Reproducir anotando la secuencia: al confirmar el borrado, **¿desapareció la sheet de Ajustes?** ¿El
  título de la pantalla que quedó era el **nombre del grupo** (detalle) o «Ajustes»?
- ¿El detalle seguía mostrando los gastos, o se quedó vacío?
- ¿Salió algún alert (`GroupSettingsView.swift:155-159`)? ¿Con qué texto?
- ¿El grupo tenía deuda pendiente? (con deuda el botón va deshabilitado, `:568`; que apareciera
  **habilitado** ya dice que no).
- Captura o vídeo del instante posterior al segundo tap de confirmación. Es lo único que zanja la
  distinción entre las hipótesis 1 y 2.
- Repetir con el grupo abierto **desde la lista** y también entrando por deeplink/notificación: son
  pilas de navegación distintas.

## Cuando se implemente (nada de esto entra en este ticket)

- Decidir el criterio de auto-cierre del detalle para un grupo soft-deleted. `GroupDetailDismissDecision`
  es lógica pura y ya tiene tests, así que ampliarla es barato — pero **elegir después** de saber qué
  pantalla se quedó abierta, porque si el problema fuese la sheet, tocar esa función no arregla nada.
- Decidir qué se le dice al usuario: hoy el éxito del borrado es solo háptica.
- Regla anti-drift del repo: tocar código bajo `Yala/` obliga a actualizar el área correspondiente de
  `qa/coverage-index.json` en el MISMO commit — `groups-crud-balances-settlements` cubre los ficheros
  de pantalla y `GroupService.swift`; `GroupDetailDismissDecision.swift` hoy no está en ningún glob.
  Este ticket no toca código, así que aquí no hay nada que actualizar todavía.

## Distinto de (no duplicar)

- **`groups-leave-rpc-error-10`** — la corrida **anterior**: en el teléfono **B** falló **salir** del
  grupo con «GroupsRPCError 10» y **no** aparecía botón de borrar. Aquí, en **A**, el botón **sí**
  apareció, el borrado no dio error, y lo que falla es que **la pantalla no se va**. Otro teléfono,
  otra acción, otro síntoma. Este ticket **no** lo cierra ni lo reescribe. Medido: ese id **no tiene
  fichero en `tickets/` en este árbol** — vive en una PR abierta a `2.1`, sin mergear al escribir esto.
- `groups-ghost-tx-on-delete` (hoy en `tickets/qa/`) — la TX fantasma al borrar un **gasto** de grupo:
  ahí el defecto es el dato que sobrevive, vía el bridge de gastos. Aquí el dato se guarda bien (la
  lista ya lo oculta) y lo que sobrevive es **la pantalla**.
- `orphan-alerts-behind-fullscreen-covers` (`tickets/backlog/`) — mismo terreno (capas de presentación)
  pero al revés: allí un alert que el usuario **no ve** porque queda detrás de un cover; aquí una
  pantalla que el usuario **sí ve** y no debería seguir ahí.
- `groups-reconnect-prune-or-rewire` y `rescue-discarded-groups-pull` — maquinaria de reconexión y
  rescate del pull de grupos. Otro sujeto.

## Implementación (2026-09-05)

Todo lo de abajo está medido en el árbol de la rama, no heredado de la sección anterior.

- **`Yala/App/Logic/GroupDetailDismissDecision.swift`** — `shouldDismiss` gana el parámetro
  `isHiddenForAll` y la rama `contextIsNil || isDeleted || isHiddenForAll`. **Sin valor por defecto a
  propósito**: con default, un callsite futuro que lo olvidara decidiría «no borrado» en silencio; sin
  él, el compilador lo señala. Hoy el callsite es uno solo.
- **`Yala/App/Views/Groups/GroupDetailView.swift`** — el `onChange(of: sessionState.dataVersion)` pasa
  `group.isHiddenForAll`. Una línea; no se tocó el orden dismiss-first ni nada más de la vista.
- **`YalaTests/GroupDetailDismissDecisionTests.swift`** — los 6 tests existentes migran a la firma
  nueva y entran 4: el caso del device, el borrado sobre un grupo abierto YA archivado (donde la rama
  del archivado no cierra y el cierre depende enteramente del flag), el que llega por sync, y un
  control negativo. 10/10 en verde.
- **`qa/coverage-index.json`** — `groups-crud-balances-settlements`: entra el glob de
  `GroupDetailDismissDecision.swift` (antes no caía bajo **ninguno**), nota de cobertura y
  `lastVerified` a 2026-09-05.

**Lo que NO se tocó**, por alcance: la semántica de `softDelete` en servidor, el diseño de la sheet de
Ajustes, y el copy — no hay toast ni alert nuevo. El AC de «señal de que ocurrió» se cumple por su
segunda vía, la que el propio criterio admite: **el cierre lo hace evidente**. El usuario aterriza en
la lista y el grupo no está. Añadir copy habría pedido 7 idiomas para un caso que la navegación ya
resuelve.

### Sin equivalente a `wasArchivedOnAppear`, y por qué

Un grupo archivado es un destino legítimo —tiene su sección en la lista—, así que la decisión respeta
al que entró a propósito. Uno soft-deleted no lo es: **las cuatro puertas al push del detalle**
(`GroupsContainerView` :398, :450, :499 y el deeplink de `openPendingGroupIfAvailable`) salen de
`activeGroups`/`filteredGroups`, y ambas filtran `!isHiddenForAll` (`GroupsViewModel` :78, :82). No
existe el caso «entré a propósito a un grupo oculto». Por eso el fix cubre la transición y no hace
falta comprobarlo también en `onAppear`.

### Verificación

- **Unit:** 10/10. **Mutante verificado:** quitar `|| isHiddenForAll` pone en rojo exactamente los
  tres `softDeleted*` y deja los otros siete en verde — el control negativo incluido.
- **Simulador** (iPhone 17 Pro, seed `grupos-saldado`, grupo «Viaje a Lima», owner, sin deuda):
  - *Con el fix*: al confirmar, la app aterriza en la **lista de Grupos** y el grupo ya no aparece.
    Sin tocar Atrás.
  - *Sin el fix* (mismo recorrido, mutante compilado): el detalle **se queda abierto** con su título y
    sus gastos. Es el reporte del owner, reproducido.
- De camino se confirmó el gate de deuda: en «Viaje a Cusco» (deuda viva entre otros dos miembros) el
  botón de borrar sale deshabilitado con su hint, aunque el balance propio esté a cero.

## Acceptance Criteria

- [x] Tras confirmar el borrado del grupo, el usuario **no** se queda delante del grupo borrado: la app
      lo devuelve a la lista de Grupos sin que tenga que tocar Atrás. — verificado en simulador.
- [x] El borrado deja una señal de que ocurrió (hoy el éxito solo hace háptica), o el propio cierre lo
      hace evidente. — por la segunda vía: el cierre. No se añadió copy.
- [x] Queda cubierto por test el criterio de cierre del detalle para un grupo soft-deleted, de modo que
      no dependa de que el usuario navegue a mano. — 4 tests nuevos, mutante verificado.
- [x] Antes de tocar código: queda anotado en este ticket **qué pantalla** era la que se quedó abierta
      (la sheet de Ajustes o el detalle en push). Sin eso, el fix se elige a ciegas. — **el detalle en
      push**, reproducido en simulador antes de elegir el fix.

**Queda para device-QA**: repetir en teléfono real, sobre TestFlight, el recorrido del reporte
original (owner, grupo con gastos y sin deuda). Lo verificado aquí es simulador; el reporte venía de
device y ahí no hay traza. Vale también entrar al grupo por deeplink/notificación antes de borrar: es
otra pila de navegación y el simulador solo cubrió la entrada desde la lista.

## QA Visual · 2026-09-16 — PASS

Simulador iPhone 17 Pro (iOS 26.5), sobre `2.1` @ `bebd57a57`, `Yala Dev`, `-uitest-reset -uitest-skip-onboarding -uitest-seed grupos-saldado`.

Grupos → «Viaje a Lima» → Ajustes del grupo → «Eliminar grupo» → «¿Eliminar este grupo?» → Eliminar →
**aterriza en la lista de Grupos, ya sin «Viaje a Lima»**. El detalle no se queda abierto.

Captura: [vuelve a la lista](../../qa/evidencia-barrido-20260916/23-grupo-eliminado-vuelve-a-la-lista.jpg).

**No se vio la entrada por enlace o notificación** que pedía la nota de device-QA. Se intentó en frío
con `-uitest-deeplink-url yala://groups/seeded-first` sobre `grupos-saldado`, y la app abrió la lista de
Grupos, no el detalle ([captura](../../qa/evidencia-barrido-20260916/40-deeplink-seeded-first-abre-la-lista-no-el-detalle.jpg)):
el seam no sirve para esta entrada. Por código (leído, no ejecutado), la notificación
(`NotificationService.swift:45-60`) y la URL (`AppBootstrapper.swift:2300-2305`) emiten el mismo destino
`.groupDetail` y llegan al mismo `navigationDestination` (`GroupsContainerView.swift:225`); el cierre vive
en `GroupDetailView.swift:268-285`, sin rama por la forma de entrar. Los cuatro criterios del ticket
están marcados, así que se cierra.
