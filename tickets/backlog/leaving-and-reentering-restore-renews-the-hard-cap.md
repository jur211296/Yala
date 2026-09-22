---
id: leaving-and-reentering-restore-renews-the-hard-cap
status: backlog
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
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
