---
id: late-notice-of-a-welcome-private-session-purges-groups-joined-later
status: done
priority: medium
area: "groups, onboarding, modo-nube"
created: 2026-09-27
source: "hallazgo de `activation-private-gate-leaves-a-late-notice-that-purges-groups` (2026-09-27); inferido por lectura, NO reproducido"
updated: 2026-09-28
qa-status: not-replicable
qa-date: 2026-09-28
qa-notes: barrido 2026-09-28 sin device-QA - pide una invitacion desde otro telefono y empezar sin red; cubierto por WelcomeLateNoticeKeepsJoinedGroupsTests
---

# El aviso tardío de quien empezó en el Welcome se lleva los grupos a los que se unió después

## El síntoma, en lenguaje de usuario

Empiezo Yala con «Es mi primera vez → privado» sin iCloud (o sin red). Semanas después me uno a un grupo. Cuando iCloud
vuelve, aparece «Encontramos datos tuyos en iCloud». Si elijo «Empezar de cero», además de mis registros se van mis grupos
de este teléfono y la sesión de Grupos, aunque el aviso solo nombra «tus registros, tus cuentas y tus presupuestos».

## Lo medido (2026-09-27, leyendo código)

- El testigo del espejo tardío lo escribe la puerta del Welcome (`continueWithoutValidating`).
- Fuera de una sesión nacida de «Activar Yala completo», el aviso borra con `.handover`
  (`ICloudWipeScope.lateNotice(sessionBornFromFullActivation: false)`): sube los cambios de grupos pendientes, purga el
  dominio local, lo sella y retira la sesión de Grupos (`DataWipeService.wipeLocalGroupsDomain`).
- `.handover` es la frontera de «aquí empieza otro usuario», y la propia doc de `ICloudWipeScope` dice que quien contesta
  al aviso tardío es la misma persona. Los grupos siguen en el backend: se recuperan entrando otra vez.

## Qué hay que decidir

El mismo aviso termina también el borrado a medias de la puerta del Welcome (`.leaveForLateNotice`), y ahí el dominio
puede ser de otra persona. Separar los dos casos pide saber de quién son los grupos: ¿se unió a ellos después de su
elección privada, o estaban de antes? No hay hoy un hecho durable que lo diga.

## Criterios de aceptación

- [x] «Empezar de cero» del aviso tardío no se lleva grupos a los que la persona se unió después de elegir privado.
- [x] El borrado a medias del Welcome sigue sellando el dominio de quien usó el teléfono antes.

## Decisión (2026-09-27, MODO AUTÓNOMO)

**Lo que decide el alcance es QUÉ borrado hace el aviso, no quién contesta.** El aviso hace dos cosas distintas:

- **Empezar un borrado** («Empezar de cero» con el corpus de iCloud) → `.importedRows` para todas las sesiones. El
  testigo solo lo dejan dos puertas, y las dos garantizan que los grupos del teléfono son de la persona: la del Welcome
  sigue al onboarding privado, que solo arranca con el teléfono vacío (grupos incluidos) o tras borrarlo con el
  handover; la de la activación existe para conservarlos.
- **Terminar un borrado** («Terminar de borrar» y la reanudación del arranque) → el alcance con que ese borrado ENTRÓ. Lo
  apunta el propio borrado al empezar (`StorageModePersistence.recordICloudCorpusWipeScope`, antes del primer `await`),
  como sub-estado del arm que sobrevive al paso a «a medias». Así el borrado a medias del Welcome se termina con su
  `.handover` y sigue sellando el dominio de la persona anterior.

Sin apunte (un borrado armado con un build anterior) manda la marca de #280, como antes. No se inventó un hecho
frágil sobre cuándo se unió la persona a cada grupo: el apunte lo escribe quien sabe el alcance y vive lo que el borrado.

## Qué cambia para el usuario

Quien empezó Yala en privado sin iCloud y después se unió a grupos sigue viendo «Encontramos datos tuyos en iCloud» cuando
iCloud vuelve. Si elige «Empezar de cero», se borran sus registros, cuentas y presupuestos (en iCloud y en el teléfono);
**sus grupos, sus saldos y su sesión de Grupos se quedan**, y vuelve al onboarding personal con su nombre y su divisa.
Sus gastos y liquidaciones de grupo reaparecen en lo personal en el arranque siguiente. Lo mismo si el borrado se corta y
lo termina «Terminar de borrar» o el arranque.

Quien dejó a medias el borrado de la puerta del Welcome (con datos de otra persona en el teléfono) no cambia: «Terminar
de borrar» se sigue llevando todo, grupos incluidos.

## Verificado

- Unit: `YalaTests/CloudSync/WelcomeLateNoticeKeepsJoinedGroupsTests` (tabla de empezar/terminar, vida del apunte,
  cadena hasta el dominio de Grupos con control positivo, la salida «sin iCloud» de la puerta y el cableado) + los scans
  ajustados de `ActivationLateNoticeKeepsGroupsTests`, `ActivationRestoreDiscardTests` y `WelcomePrivateICloudGateTests`.
- Mutantes: 13/13 muertos (empezar con `.handover`, terminar ignorando el apunte, las cuatro reglas de vida del apunte,
  el aviso y la reanudación con el valor equivocado, el borrado sin apuntar, las señales bajadas a ciegas, `resolve` sin
  mirar «a medias», `.zoneOnly` pisando un «a medias», y la salida «sin iCloud» sin retirar la marca en la lógica y en la
  vista).
- Gate: build de `Yala` y `Yala Dev` sin warnings nuevos; 8293 unit en 794 suites, 0 fallos; 10 XCUITest
  (`OnboardingFlowUITests`, `WelcomeChooserUITests`) con el centinela solo.
- Review adversarial de tres lentes:
  - **premisa y alcance**: un camino real al mismo bug por «Terminar de borrar» — salir de la puerta del Welcome sin
    iCloud con el teléfono medido vacío dejaba «a medias» puesto, y tras el onboarding su `.handover` purgaba los grupos
    unidos después. Arreglado aquí (`unverifiedExitRetiresHalfway`). El testigo que sobrevive a «Restaurar» va a
    `late-notice-witness-survives-a-welcome-restore-over-device-data`.
  - **vida del apunte**: la puerta privada de la activación podía pisar el apunte de un «a medias» con `.zoneOnly`
    (teórico hoy): ya no apunta lo que no llega a las filas. Y «Terminar de borrar» desde el propio aviso con el corpus
    pasa a leer el apunte (`LateWipe.resolve`).
  - **después del borrado**: cancelar el onboarding y empezar de cero en el Welcome purga los grupos conservados, con su
    alert → `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`; la hoja desmontada tras un borrado
    que terminó cambia de consecuencia → anotado en `late-icloud-notice-wipe-cancelled-after-it-committed-skips-its-exit`.
    El caso del test que repetía la tabla ahora recorre `resolve` leyendo el disco.
- Copy: `wipeConfirmBody` ya describe el alcance. `leftHalfwayConfirmBody` («Se borra lo que queda en este teléfono…»)
  promete algo más de lo que borra cuando el borrado a medias era del propio aviso (los grupos se quedan); es el mismo
  texto que #280 dejó para la activación, y promete de más, no de menos.

## Guion de QA en iPhone (opcional; no bloquea)

Hace falta un Apple ID con datos viejos de Yala en iCloud y un grupo al que unirse (una invitación de otro teléfono).

1. Borra Yala e instálala. Activa el modo avión.
2. Welcome → «Es mi primera vez» → privado. Debe salir «No pudimos revisar tu iCloud» → «Seguir así». Termina el
   onboarding.
3. Quita el modo avión y únete al grupo desde la invitación. Comprueba que el grupo aparece en Grupos.
4. Cierra Yala del todo (deslizar en el selector de apps) y ábrela.
5. Debe salir «Encontramos datos tuyos en iCloud». Toca «Empezar de cero» → «Borrar todos los datos».
6. **Comprueba**: vuelves al onboarding personal (no al Welcome) y en Grupos sigue el grupo, con sus saldos, sin pedirte
   iniciar sesión otra vez.
7. Termina el onboarding, cierra y abre Yala: los gastos de ese grupo vuelven a salir en Registros.

## Relacionados

- [[activation-private-gate-leaves-a-late-notice-that-purges-groups]]
- [[late-notice-witness-survives-a-welcome-restore-over-device-data]] (residual que sale de la premisa de arriba)

## Barrido de `qa` · 2026-09-28 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido semanal (encargo `2026-09-28-barrido-qa-in-qa-semanal`), con el criterio del 2026-09-23 (#224). Pide empezar en privado sin red, unirse a un grupo con una invitación de otro teléfono y esperar el aviso tardío: un caso raro. Lo cubren `WelcomeLateNoticeKeepsJoinedGroupsTests` y `WelcomePrivateICloudGateTests`.
