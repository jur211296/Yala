---
id: detach-saves-the-personal-graph-outside-the-quiescence-window
status: done
updated: 2026-10-02
priority: medium
area: "modo-nube, groups, swiftdata"
created: 2026-09-11
source: "review adversarial del paso 10 (`groups-account-association-in-storage-row`), lente de sync"
---

# El des-puenteo del desasociar escribe el grafo PERSONAL fuera de la ventana de quiescencia que se comprobó

## Lo medido (2026-09-11)

`CloudSessionSignOut.detachGroupsAccount` reusa `pushGroupsForSignOut`, cuya quiescencia del store
personal (`awaitPersonalQuiescenceForGroupsSignOut`) se comprueba **dentro de `attemptGroupsOnlyClose`**,
o sea antes del push-all. Entre esa comprobación y el `context.save()` de
`GroupsAssociationDetach.detachBridge` pueden pasar hasta 20 ciclos de push con red, sus `sleep` de 250 ms
y un `await CloudAuthService.signOut()`.

En `.icloud` el mirror de CloudKit está VIVO y el `mainContext` es compartido por los tres stores: si en
esa ventana arranca un import, el save entra sobre un store a medio asentar — el `_assertionFailure` de
SwiftData que no atrapa ningún `do/catch` y que es la clase del crash-loop de restore.

Dos cosas lo hacen distinto de sus hermanos del paso 9, y las dos empeoran el caso:

- Es el primer camino de la familia que escribe el **grafo personal** (`TransactionItem`, `InboxDraft`) y
  no solo filas de sync-meta.
- Es el único que **no** termina en boot-wipe + relanzamiento, que en los otros enmascara el destrozo.

## Lo que se espera

Re-comprobar la quiescencia justo antes del `save()` del des-puenteo (el gate ya existe y es barato de
volver a pedir), o mover el des-puenteo delante del push-all — con el coste, entonces, de que un bloqueo
del push deje el puente ya soltado, que es peor. La primera opción es la que conserva el orden actual.

## Cómo se prueba

Con el andamio on-disk de los tres stores y el seam del gate de quiescencia: forzar «no quieto» entre el
push y el save, y exigir que el desasociar espere o se bloquee en vez de guardar.

## Hecho (2026-10-02)

- El puente y el borrado del desasociar escriben por un solo sitio, `CloudSessionSignOut.writeDetachUnderQuiescence`:
  vuelve a pedir la puerta de quiescencia (`awaitPersonalQuiescenceForGroupsSignOut`, la de siempre) y después hace los
  dos `save()` sin un solo `await` entre medias. El orden del gesto no cambia.
- Sin quietud a tiempo, el gesto se para sin escribir nada con `.bridgeUnreadable` («No pudimos revisar los movimientos
  de tus grupos… No se soltó nada. Vuelve a intentarlo»). `.transient` habría dicho «quedan cambios sin subir», falso aquí.
- La espera abre una ventana que antes no existía (entre comprobar la sesión y los `save()` no había un `await`), así
  que el escritor vuelve a mirar la condición de quien llama tras la puerta, síncrona (`stillMayWrite`, obligatorio):
  en el gesto, que el llavero siga sin sesión (si volvió, `.sessionNotClosed` y su canario con `after=quiescence`); en
  el reintento, que la sesión viva no sea la de la cuenta pendiente (si lo es, `.busy`, como su guard de entrada).
- El reintento del borrado (`retryDetachPurge`) pasa por la misma puerta: era la única purga del coordinador sobre el
  contexto compartido sin quiescencia. Sin quietud devuelve `.purgeFailed` sin canario y la marca sigue armada.
- Tests: `GroupsDetachQuiescenceWindowTests` (tres stores on-disk + seam de la puerta: no quieto ⇒ nada en memoria ni en
  disco; quieto tras esperar ⇒ la puerta corre antes de tocar nada; reintento con y sin quietud; cableado por
  source-scan). Ajustados los escáneres de orden de `GroupsDetachPurgeFailureTests` y `GroupsDetachSessionSurvivesTests`.
- Mutantes, 7 de 7 muertos: sin puerta, puerta detrás del puente, `Task.yield()` tras la puerta, reintento con puerta
  propia, `.transient` en vez de `.bridgeUnreadable`, sin la re-comprobación de la condición, y `break` en la rama sin
  quietud del reintento.
- Hallazgos de la review, en tickets nuevos: `detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`
  y `detach-quiescence-timeout-says-group-changes-are-pending`.
- Device-QA: no aporta. Exige un import de CloudKit a medio asentar justo en la ventana, que no se puede provocar a mano.
