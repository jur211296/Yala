# Restaurar: timeout de import ≠ vacío; confirmar antes de Empezar desde cero

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, tickets/ + docs/TICKETS.md, merge a 2.1 y /cerrar-total SIN preguntar.
Bugs/decisiones nuevas → ticket --solo-crear antes de cerrar.
NO pidas go, ni confirmación de plan, ni «¿le doy?». La decisión de producto YA está tomada abajo.
Ambigüedad NUEVA de producto/acceso: es NOCHE Lima (21:00–06:00) — elige lo recomendado alineado con la decisión 1+3 y regístralo; si es demasiado gordo para asumir, aparca en ticket propio y sigue con lo implementable.

## Contexto
Ticket: `tickets/backlog/restore-says-no-data-when-the-icloud-import-never-settled.md` (high).
Sale del review de #193 (`reinstall-without-network-has-no-cloud-door`). Población mayor: basta que CloudKit tarde >90 s.

Problema: tras timeout de `waitForImportQuiescence`, Restaurar dice «No encontramos tus datos» y «Empezar desde cero» borra SIN confirmar.

## Decisión Jürgen (2026-09-17) — MANDATORIA
**1+3:**
1. Distinguir timeout vs vacío con señal del import (`hasObservedImportActivity` / `lastImportError` u equivalente medido) — copy «seguimos trayendo tus datos» (no negar existencia).
3. Confirmar antes de «Empezar desde cero» en `.notFound` cuando la búsqueda/import no asentó.
No ahora: opción 2 sola (subir/adaptar tope 90 s) como remedio principal.

## Qué se pide
Implementar 1+3 según criterios del ticket. Tests de comportamiento (timeout≠vacío; confirmación en notFound no asentado; usuario realmente nuevo no se convierte en «no pudimos comprobar» por el mismo tope). PR a `2.1`. Board + `docs/TICKETS.md`. `/cerrar-total`.

## Modo noche
Sin AskUserQuestion. Elige recomendado; aparca solo si la decisión nueva es demasiado importante.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no git) cuando:
(1) decisión/acceso real de Jürgen; (2) PR abierto; (3) vas a /cerrar-total — resumen usuario; (4) idle sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, CI advisory.

## Qué NO tocar
marketing/, Web/. No reabrir #193 salvo acoplamiento. No opción 2 como único fix.

## Criterio de hecho
Criterios del ticket + gate verde + PR mergeado a 2.1 + board al día + /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo · bypass, noche Lima 2026-09-20)

Nadie estaba delante: cada nodo se contestó con la recomendación propia, alineada con la decisión
1+3 de Jürgen del 2026-09-17, y queda aquí para poder discutirse en el PR. La versión con las
coordenadas medidas vive en el ticket
(`tickets/in-progress/restore-says-no-data-when-the-icloud-import-never-settled.md`).

## Paso 0 — árbol de decisiones resuelto (2026-09-20, sesión autónoma)

Las siete se resolvieron ANTES de escribir código, y cada una con su medición.

**D1 · La señal son DOS términos, y el segundo lo puso la review.** El primero es
`hasObservedImportActivity`: medido en `Yala/Services/iCloudSyncService.swift:346`, `case
.importEvent` lo pone a `true` **antes** del `if let error`, y un store vacío no llega nunca a ese
`case` (su docblock, líneas 86-92, y la H-2026-07-18-8 de `BootSaveGateLogic`).

**Y ese mismo orden es lo que obliga al segundo término, que el Paso 0 falló.** La versión original
de esta decisión descartaba `lastImportError` por «redundante, porque todo error de import implica
ya la actividad» — justo al revés: es el error el que queda INVISIBLE, porque la actividad se lo
traga. Lo cazaron **las tres lentes de la review a la vez**, con dos poblaciones: quien tiene un
fallo terminal (cuota, cuenta gestionada, permisos) y —peor— **el usuario realmente nuevo con red
inestable**, a quien un solo `.importEvent` con `networkUnavailable` le enciende el flag con la
cuenta vacía. Los dos leían «seguimos trayendo tus datos» con un «Reintentar» que devolvía al mismo
sitio indefinidamente: el remedio que Jürgen descartó, por la puerta de atrás.

El segundo término es **la palabra VIGENTE de CloudKit**, y no se inventa: es el molde que la
reversa ya usa (`ICloudCutoverGateLogic.decide`, `ReverseUploadBlockerLogic`). `lastImportError` a
secas sigue sin valer —es un latch que ningún import con éxito limpia, igual que su gemelo del
export—, así que se comparan las fechas, y para eso `lastImportErrorAt` se añade espejando
`lastExportErrorAt`. Un error sin fecha no cuenta: la ambigüedad nunca convierte «los datos vienen»
en un desenlace que los niegue.

Con el error vigente el desenlace es `.inconclusive`, **no un cuarto copy**: los tres finales del
camino de siempre —`.cloudPaused`, `.cloudUnverified`, `.notFound`— o afirman que los datos existen
o no niegan nada, los tres ofrecen reintentar y los tres confirman antes de borrar.

**D2 · Estado propio, no una variante de copy.** Molde de `WelcomeRestoreEmptyOutcome`: dos
hechos distintos sobre los datos del usuario son dos estados. `.importIncomplete` dice «Seguimos
trayendo tus datos» y no niega nada.

**D3 · El import gana la precedencia y CORTA la consulta de red.** Con actividad de import
observada ya sabemos que hay datos bajando **por CloudKit**, y el kill-switch remoto gobierna el
backend propio, no el espejo de Apple: preguntar no puede cambiar el desenlace. Además ahorra un
fetch más a quien ya esperó 90 s.

**D4 · `.notFound` confirma SIEMPRE, y el término del ticket se midió antes de escribirlo.** La
decisión pide confirmar «cuando la búsqueda/import no asentó», así que el primer intento llevó ese
término en el estado (`.notFound(conclusive:)`) con la rama concluyente llamando directo, «para no
ponerle un diálogo de más a quien estrena la app». **Eso era falso y lo dice el código**: `settled`
exige `hasCompletedFirstImport` (`iCloudSyncService.swift:586`), que exige un `.importEvent`
exitoso, que exige que CloudKit trajera algo — y un store vacío no dispara eventos. ⇒ el usuario
realmente nuevo **nunca** asienta, así que «cuando no asentó» y «siempre» son hoy el MISMO
comportamiento para él.

Y peor: la rama concluyente sí tenía una población, **y es gente con datos**. Si CloudKit trajo algo
y `hasAnyData` sigue en `false`, lo que trajo son presupuestos o grupos, que ese predicado no cuenta
(`iCloudSyncService.swift:773-775`). O sea que el `if` le daba el borrado de un toque exactamente a
quien pretendía proteger. Se retira el término —y con él `isConclusive`, que se queda sin
consumidor— y el hueco de `hasAnyData` sale en ticket propio:
`restore-treats-budgets-and-groups-as-no-data`. **El copy de `.notFound` no cambia**: Jürgen
descartó convertir al usuario nuevo en un «no pudimos comprobar», y la señal del import no lo separa
del teléfono al que CloudKit no contestó.

**El mutante moría y el término sobraba igual.** Cablear `isConclusive` a `true` fijo mataba 5
casos, así que parecía cubierto; lo que faltaba medir no era el test, era la población.

**D5 · `.iCloudDisabled` también confirma, y su población TIENE datos.** Lo cazó leer la rule de
área contra el diff, no las tres lentes. La puerta que manda a ese estado es `startSearch` con
`iCloudSyncService.isAccountAvailable`, que es `SwiftDataConfiguration.isICloudAvailable()` =
`FileManager.default.ubiquityIdentityToken != nil` (`Yala/Utils/SwiftDataConfiguration.swift:36-38`,
medido). **Ese token mide iCloud DRIVE, no CloudKit** — regla del 2026-09-10 en
`.claude/rules/swiftdata-cloudkit.md`: con Drive apagado y la sesión de iCloud viva el token es
`nil` mientras CloudKit funciona perfectamente, y el mount que sale de ahí adjunta el espejo igual.
⇒ quien cae en esta pantalla puede tener su histórico entero en el servidor, y hasta hoy lo tiraba
de un toque. **Es el mismo bug del ticket por otra puerta**, y cae de lleno en el criterio de
aceptación 2.

Y el test que lo prohibía se refuta por su propio criterio, no por uno nuevo:
`RestoreStartFreshGateTests.bothStatesThatClaimDataStillConfirm` lo mete en el bucle de «estados
que NIEGAN que haya datos» y escribe «el criterio es negar, no callar» — su copy no niega nada.
`es-419.lproj/Localizable.strings:4101` dice «Necesitas tener iCloud activado para **recuperar tus
datos**»: los presupone.

**D6 · `.wiped` se queda llamando directo.** Es el único desenlace concluyente **por acto del
propio usuario**, y ahí la confirmación preguntaría por algo que él acaba de decidir.

**D7 · El copy nuevo describe lo observado, sin prometer.** Dice que iCloud sigue enviando el
historial y que con mucho movimiento o conexión lenta tarda; no promete que los datos existan ni
da un tiempo. Icono `icloud.and.arrow.down` y tinte de acento —no gris de vacío ni naranja de
fallo—: esto no es un error, es algo en marcha.


## D8 · lo que la review cambió, y lo que mandó a tickets propios

Cuatro lentes: poblaciones, concurrencia/ciclo de vida, tests/copy/l10n, y la rule de área leída
CONTRA el diff. **Lo que cambió el código** está arriba (D1 y D5) más tres cosas:

- **`.iCloudDisabled` gana el botón de volver a buscar.** Era el único de los estados «puede tener
  datos» sin él, y `startSearch` cuelga de un `.task` que corre UNA vez: quien seguía el consejo
  primario de esa pantalla —«Actívalo en Ajustes y vuelve a intentar»— se encontraba al volver
  exactamente la misma pantalla. **Su mutante SOBREVIVÍA**, así que además lleva test.
- **El test de cableado acotaba mal.** Intercambiar los dos cuerpos del `if` de la closure compilaba
  y dejaba las cuatro aserciones verdes: el bug entero de vuelta, con el enum nuevo puesto. Ahora
  cada rama se acota hasta la siguiente, como ya hacía `eachOutcomeMapsToItsOwnState`.
- **Dos anclas y dos docblocks míos que mentían**: un `expectOrder` sobre `sleep(0.8)` (un número de
  UX que alguien toca sin que el invariante cambie ⇒ rojo falso esperando), dos aserciones
  tautológicas, un comentario que aún hablaba del `conclusive:` retirado, y el docblock de L10n que
  decía «no da un tiempo» sobre un copy que dice «unos minutos».

**Lo que NO se toca aquí, con ticket propio cada uno:**

| Ticket | Qué | Por qué no aquí |
|---|---|---|
| `restore-back-and-reenter-closes-the-live-session-window` (high) | Salir y volver a entrar apaga la ventana del flujo vivo: el latch enciende idempotente y apaga incondicional | Previo al cambio; toca `ICloudRestoreSessionSignal` y una garantía con test propio |
| `restore-treats-budgets-and-groups-as-no-data` (medium) | `hasAnyData` ignora presupuestos y grupos | Previo; toca también `.found` y la puerta privada |
| `start-fresh-dialog-promises-what-the-gate-undoes` (medium) | El copy del diálogo promete un alta y lo que abre es una puerta | Previo; copy compartido por cinco estados y 16 locales |
| `restore-empty-state-resolution-cannot-be-cancelled` (low) | El `guard !Task.isCancelled` de `resolveEmptyState` no puede disparar | Previo y benigno hoy |
| `import-activity-flag-describes-the-process-not-the-search` (low) | La señal es monótona por proceso, no por búsqueda | Acotado tras cerrar el caso del import que falla |

## Guion de device-QA (iPhone, 7 pasos)

**CloudKit no existe en simulador**, así que nada de esto se puede medir aquí. Hace falta un iPhone
con dos Apple ID: **A** con histórico grande de Yala en iCloud, **B** sin nada de Yala.

1. **Reproducir el bug.** Apple ID A. Network Link Conditioner en «3G» o «Very Bad Network».
   Reinstalar Yala → «Ya tengo cuenta» → «Restaurar desde iCloud». Esperar a que pase el tope.
   **PASA si** sale «Seguimos trayendo tus datos» y **no** «No encontramos tus datos».
2. **La salida existe.** En esa pantalla, «Reintentar búsqueda» vuelve a la barra de progreso con
   los conteos subiendo. Quitar el condicionador y reintentar: debe terminar en la pantalla con las
   cifras.
3. **EL PASO QUE DECIDE — el usuario nuevo no queda atrapado.** Apple ID B, **sin** condicionador.
   Reinstalar → Restaurar. **PASA si** sale «No encontramos tus datos» (el copy de siempre) y
   **falla si** sale «Seguimos trayendo tus datos»: eso significaría que la señal está mal y toda
   instalación nueva quedaría esperando un import que no existe.
4. **La confirmación.** En el paso 3, pulsar «Empezar desde cero». **PASA si** pregunta antes.
5. **El import que falla no promete.** Apple ID B con el avión puesto tras abrir la app (para que
   CloudKit emita un evento de import con error de red). Restaurar. **PASA si** sale «No pudimos
   comprobar tus datos» o «No encontramos tus datos», y **falla si** sale «Seguimos trayendo tus
   datos»: ahí no viene nada.
6. **iCloud Drive apagado.** Ajustes → Apple ID → iCloud → apagar iCloud Drive. Abrir Yala →
   Restaurar. **PASA si** (a) sale «Activa iCloud para continuar», (b) hay botón de recargar arriba
   a la derecha, y (c) «Empezar desde cero» pregunta antes.
7. **El log.** Console.app filtrando por `RestoreFlow`: cada búsqueda deja `SETTLED phase=… import=…`
   con `settledEmpty` / `stillImporting` / `inconclusive`, y el caso del paso 1 deja además
   `IMPORT-INCOMPLETE`.

**Lo que este guion NO cubre y se dice para que nadie lo lea de más:** que el import termine de
verdad tras el «Reintentar» depende de la cuota y la velocidad de CloudKit ese día; y el paso 5
fuerza un error de red, no uno terminal de cuota o cuenta gestionada, que no se pueden montar.
