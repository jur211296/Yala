---
id: leaving-and-reentering-restore-renews-the-hard-cap
status: qa
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
updated: 2026-09-21
source: "medido por las tres lentes de la review de `restore-timeout-closes-the-session-window-with-the-import-still-running`, 2026-09-21"
---

# Salir de Restaurar y volver a entrar renueva el tope duro de la ventana de sesión

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo: esto es una puerta que se queda entornada más de lo previsto.
Quien tiene en la mano un teléfono con los datos de otra persona puede mantener abierta —todo el tiempo
que quiera, con dos toques cada vez— la ventana que permite entrar en la cuenta sin que la app avise de
que ese corpus es ajeno.

## Medido (2026-09-21)

`ICloudRestoreSessionSignal.noteRestoreStarted` re-ancla el reloj cuando la ventana está HUÉRFANA y hay
descarga detrás:

```swift
if restoreStartedAt == nil || (currentFlow == nil && hasObservedImportActivity) { restoreStartedAt = now }
```

El segundo término es un latch **monótono del proceso**: `hasObservedImportActivity` se enciende con el
primer `.importEvent` y no se apaga nunca. Así que a partir de ahí, **cualquier** salida-y-vuelta de
Restaurar estrena ventana de 600 s:

1. `.restore` → «Empezar desde cero» → `go(to: .restoreDiscardGate)` (`FullModeActivationView:216`)
   desmonta `WelcomeRestoreView` → su `onDisappear` suelta la titularidad → ventana huérfana.
2. En la puerta, «Volver» → `onBack: { go(to: .restore) }` (`:174`) → remonta → `.task { startSearch() }`
   → `currentFlow == nil && hasObservedImportActivity` ⇒ **`restoreStartedAt = ahora`**.

Dos toques por vuelta, sin esperar los 90 s. En `ContentView` el equivalente es más largo pero igual de
alcanzable: `onStartFresh` → chooser → volver a Restaurar.

**No es una regresión de `restore-timeout-closes-the-session-window-with-the-import-still-running`**, y
conviene decirlo porque parece que sí: antes de aquel ticket el apagado incondicional ponía
`restoreStartedAt = nil` a los 90 s, así que la entrada siguiente **estrenaba** reloj igual, por la otra
rama del mismo `if`. Lo que aquel ticket cerró es el reintento **en sitio** («volver a buscar» desde
«seguimos trayendo tus datos»), que conserva la titularidad y no re-ancla. Esta superficie sigue abierta,
y su tercer criterio de aceptación no la nombraba.

**Y la salida de «Empezar desde cero» ya no es la peligrosa**: desde el mismo día apaga la ventana en su
propia confirmación, así que ese camino vuelve por `restoreStartedAt == nil`, que es la rama legítima.
Queda todo lo demás que desmonte y vuelva.

## Por qué no se arregló de paso

El re-ancla es el arreglo de `abandoned-restore-no-longer-clears-the-session-window-clock`, ratificado el
2026-09-21: quien entra, se arrepiente y vuelve siete minutos después **no debe** heredar un reloj que no
describe su descarga, porque su tope duro caducaría a media bajada y el guard se cerraría sobre el dueño
legítimo. Acotarlo sin reabrir aquello pide decidir **qué distingue una entrada nueva legítima de un
rebote**, y eso es diseño, no un `if`.

## Posibles caminos (sin decidir)

- **Un tope de proceso, no de ventana.** Un segundo reloj que nazca con el primer `noteRestoreStarted` y
  que ninguna entrada re-ancle: la ventana se re-ancla como hoy, pero nunca más allá de ese techo.
- **Contar re-anclas.** Tras N (¿2? ¿3?) la ventana deja de re-anclarse hasta que el import asiente.
- **Exigir descarga VIGENTE y no histórica.** Cambiar `hasObservedImportActivity` (latch monótono) por un
  testigo con fecha: re-anclar solo si hubo un `.importEvent` en los últimos X segundos. Es el término
  que hace monótono el agujero, y el que menos toca el diseño del hermano.

## Criterios de aceptación

- [ ] Un ciclo de salir-de-Restaurar-y-volver repetido no mantiene abierta la ventana del guard
      cross-cuenta más allá de un techo acotado y medible.
- [ ] Quien entra, se arrepiente y vuelve **una vez** siete minutos después sigue estrenando ventana con
      descarga real detrás (no se reabre `abandoned-restore-no-longer-clears-the-session-window-clock`).
- [ ] El techo nuevo se mide con un test que recorra el ciclo, no con un source-scan.

## Relación con otros tickets

- `restore-timeout-closes-the-session-window-with-the-import-still-running` — de donde sale; cerró la
  misma familia por la superficie del reintento en sitio.
- `abandoned-restore-no-longer-clears-the-session-window-clock` — aporta el re-ancla que hay que acotar
  sin deshacer.
- `restore-back-and-reenter-closes-the-live-session-window` — el token de flujo, que es lo que hoy
  distingue un intento de otro.

---

## Resuelto (2026-09-21)

### Qué cambia para quien usa la app

No hay síntoma para el dueño legítimo, y sigue sin haberlo: quien restaura sus datos entra igual que
antes, y quien se arrepiente y vuelve minutos después con la descarga viva sigue estrenando su permiso
completo. Lo que cambia está en el teléfono que tiene los datos de otra persona: **hasta hoy bastaba
un solo instante de descarga en todo el arranque para que salir de «Restaurar desde iCloud» y volver a
entrar renovara el permiso, con dos toques y para siempre.** Ahora renovarlo exige que haya una
descarga bajando de verdad en ese momento; cuando la descarga termina o muere, el ciclo deja de
renovar nada y la puerta se cierra sola.

### El mecanismo: un latch monótono se cambia por un testigo con fecha

`noteRestoreStarted` re-ancla el reloj de una ventana huérfana cuando hay «descarga detrás», y ese
«detrás» lo decidía `hasObservedImportActivity`: un **latch monótono del proceso** que se enciende con
el primer `.importEvent` y no se apaga jamás.

| | Antes | Ahora |
|---|---|---|
| ¿Hay descarga? | `hasObservedImportActivity` (la hubo ALGUNA VEZ) | `ICloudRestoreInProgressLogic.hasLiveImportActivity` (la hay AHORA) |
| Exposición del ciclo | la vida del PROCESO | la vida de la DESCARGA |

El testigo lleva dos crudos del servicio y **ninguno basta solo**, que es lo que midió la review:

- **`status.isImporting` no es exclusivo del import.** `status` es un escalar ÚNICO que comparten
  import, export y setup: lo enciende un solo sitio y lo apagan trece, entre ellos el terminal de
  cualquier export y el `.idle` con que se traga un error transitorio. Un export de diez segundos en
  el minuto 0 de una bajada de siete minutos deja `isImporting == false` los 6 m 50 s restantes.
- **Y la fecha sola tampoco**, porque un import grande emite un evento al arrancar y otro al acabar:
  entre medias pasan minutos.

`lastImportActivityAt` es el sello nuevo: el instante en que se **observó** cada `.importEvent` —no su
`endDate`, que describe el import y no lo que este proceso sabe—, monótono, y **se limpia al cambiar
de cuenta de iCloud**, porque lo lee un guard de frontera de cuenta.

### El número: 600 s, y su primera versión era falsa

La frescura es **el mismo `hardCap` de la ventana**, y esa simetría es lo que la hace defendible: si la
última señal de descarga es más vieja que eso, la ventana que el re-ancla crearía ya habría caducado
por su propio tope duro. **Los 60 s de la primera versión los tumbó la review con dos escenarios
medidos**, y los dos son el ticket hermano reabierto por mi propio arreglo: el export que pisa el
estado del espejo, y el error de import RETRIABLE —«un restore grande con la red floja», que este
repo llama el caso NORMAL— que deja `.idle` mientras CloudKit reintenta con un backoff de minutos.

### El techo con número NO se entrega, y eso es el hallazgo caro de la review

Se implementó: un reloj de la cadena de re-anclas que ningún re-ancla movía, con techo de 600 s y una
cifra publicada de 1200 s. **La review lo tumbó midiendo sus dos mitades, y se retiró antes de
commitear:**

1. **No acotaba.** `noteRestoreFinished` es alcanzable desde la UI con el import vivo: «Empezar desde
   cero» → confirmar → en la puerta de descarte, «Volver» → Restaurar. Tres toques, la puerta no borra
   nada, y la entrada siguiente ESTRENA ventana y cadena. Por debajo hay un baseline que ningún techo
   toca: la señal vive en memoria a propósito, así que **relanzar la app estrena todo**.
2. **Y sí bloqueaba al dueño legítimo, de forma permanente.** Quien vuelve a los 650 s con su descarga
   viva no re-ancla (techo agotado) y no puede estrenar (`restoreStartedAt != nil`): hereda un reloj ya
   caducado y se lleva `.blockedForeignData` sobre su propia cuenta. Y **nada vuelve a armar la cadena
   en ese proceso** — no es una ventana cada 600 s, es una oportunidad y solo una hasta matar la app.

Un mecanismo que no frena a quien quiere saltárselo y sí castiga a quien no, se retira. Lo medido está
entero en el ticket `restore-session-window-has-no-reachable-ceiling`, con los tres caminos posibles
sin decidir.

⇒ **De los tres criterios de aceptación, este ticket cierra el 2 y el 3, y el 1 a medias**: el ciclo ya
no mantiene la ventana más allá de la vida de la descarga —que es lo que el testigo puede prometer—
pero no hay un número, y el ticket nuevo dice por qué no lo hay.

### Verificación

- Build ✓ · suite completa de unit en verde (**7359 tests en 740 suites**), y 84 en las cinco suites
  del área con el filtro puesto (5 pedidas, 5 corridas).
- **9 mutantes, los 9 muertos**, y el más importante es **mi propia primera versión**: con la frescura
  en 60 s caen los dos escenarios que midió la review (el export que pisa el espejo y el error
  retriable), o sea que la red nueva sí caza el defecto que la review encontró. Los otros ocho: subir
  la frescura a 3600 (el latch de vuelta), quitar `isImportingNow`, que el export borre el sello, que
  el cambio de cuenta no lo limpie, medir contra `.distantPast` desde la vista, cablear `freshness` en
  la vista, que el encendido ignore el testigo, y que la vista vuelva a pasar el latch monótono.
- **Review adversarial de tres lentes**, y las tres cazaron defectos MÍOS: el techo entero (dos
  lentes, por sus dos mitades), los dos falsos negativos del testigo, y cuatro huecos en mi red de
  tests —la frescura no la fijaba ningún caso, el source-scan del call-site dejaba libres `now:` y
  `freshness:`, nadie afirmaba que un export no BORRARA el sello, y el test del criterio 2 se medía
  pasando el bool a mano, o sea asumiendo la conclusión.

### Residual declarado

- **Sin techo con número.** Ticket propio: `restore-session-window-has-no-reachable-ceiling`.
- **El sesgo del testigo no es gratis.** Su modo de fallo es no re-anclar, o sea cerrar antes: para el
  guard es el lado seguro, para el ticket hermano cerrar antes ES el daño. Los dos tiran del mismo
  parámetro en direcciones opuestas y el código elige la del guard a sabiendas.
- **`hasObservedImportActivity` sigue sobreviviendo a un cambio de cuenta de iCloud**: tiene otros
  consumidores y tocarlo es otro ticket — `import-activity-latch-survives-an-icloud-account-change`.

### Guion de QA (iPhone, CloudKit Production)

No se monta en simulador: exige corpus real en iCloud y un import que tarde minutos.

1. iPhone con un Apple ID cuyo Yala tenga histórico grande. Borra la app y reinstálala desde TestFlight.
2. Ábrela → **«Ya tengo cuenta» → «Restaurar desde iCloud»**. Espera a ver la barra moviéndose.
3. A los ~5 s toca **atrás**. El import sigue por debajo: la app no se queda quieta.
4. Espera **7 minutos** fuera de esa pantalla, **sin matar la app**.
5. Vuelve a «Restaurar desde iCloud» y deja la barra correr **más de 3 minutos**.
6. Toca atrás y firma con tu propia cuenta. ✅ **Tiene que dejarte entrar.** ❌ Si dice que los datos
   son de otra persona, el ticket hermano está roto — es el caso que la frescura de 600 s protege.
7. **El caso del ticket, y el que hay que mirar con calma.** Con un Apple ID **sin nada en Yala**
   (o con la app ya restaurada del todo, o sea sin descarga pendiente): entra a Restaurar, toca atrás,
   y repite ese ciclo cinco o seis veces seguidas durante **más de diez minutos**. Después firma con
   tu cuenta. ✅ **Ahora sí tiene que bloquearte**: sin descarga vigente el ciclo no renueva nada y el
   tope duro cerró la ventana. ❌ Si te sigue dejando entrar indefinidamente, el testigo está
   contestando por el latch viejo.
8. Control del otro lado: repite el paso 7 **con la descarga viva** (histórico grande, import en
   marcha). Ahí sí tiene que seguir dejándote entrar — es el dueño legítimo, y esa es la exposición
   que el ticket `restore-session-window-has-no-reachable-ceiling` recoge.
