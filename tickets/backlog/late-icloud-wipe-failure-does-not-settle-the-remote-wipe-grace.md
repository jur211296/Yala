---
id: late-icloud-wipe-failure-does-not-settle-the-remote-wipe-grace
status: backlog
priority: low
area: "sesiones, sync"
created: 2026-09-30
updated: 2026-10-08
source: "review adversarial de `wipe-data-does-not-cancel-the-remote-wipe-grace`, lentes de caminos y de timing"
---

# Un borrado del aviso tardío que falla a media lista puede encender el aviso de «tus datos fueron eliminados»

## El síntoma, en lenguaje de usuario

Contestas «Empezar de cero» en el aviso de que iCloud trae datos viejos. El borrado falla a medias y la app te lo
dice. Unos segundos después, otro aviso te dice que tus datos se borraron **desde otro dispositivo**.

## Lo medido (2026-09-30)

`wipe-data-does-not-cancel-the-remote-wipe-grace` dio a los borrados deliberados un asentamiento
(`ContentView.settleSignalsAfterDeliberateWipe`): re-mide `hasPersonalData` en la vuelta del borrado y absorbe esa
caída, para que no arranque la gracia de 5 s del aviso de vaciado remoto. Lo usan «Vaciar datos» y el restore remoto.

Quedan dos huecos del mismo patrón, los dos por la rama de FALLO:

1. **`performLateICloudWipe`, rama `return failure`** (`ContentView`). El aviso tardío con `.startFresh` borra con
   `.importedRows`, que NO resetea preferencias (`ICloudWipeScope`), así que `hasCompletedOnboarding` sigue en `true`.
   Si `wipeAllUserData` lanza con cuentas y categorías ya borradas —guarda por lotes—, se sale sin re-medir y sin
   bajar el onboarding. La caída llega en el siguiente bump de `dataVersion`, con el guard abierto y el eje en `true`
   (sesión privada, `.icloud`): a los 5 s sale el aviso. El gemelo de la activación (`.importedRows` de «Restaurar →
   Empezar desde cero») tiene la misma rama, pero ahí lo tapan el eje y `!showFullModeActivation`.
2. **La medida del asentamiento falla CERRADO.** `checkHasPersonalData` devuelve `true` si el fetch lanza, y entonces
   no se arma la absorción: la caída posterior vuelve al comportamiento de antes del arreglo, en las dos celdas que
   cubre el ticket.

**MEDIDO**: el código de las dos ramas. **INFERIDO**: que ocurra — pide un fallo de SwiftData en el momento justo.

## Arreglo probable

(1) Llamar a `settleSignalsAfterDeliberateWipe()` en la rama de fallo de `performLateICloudWipe` (y, por simetría, en
la de la activación), con su source-scan. (2) Decidir si la medida fallida debe armar la absorción: el borrado sí
ocurrió, y el error de signo aquí es callar un aviso, no borrar nada.

## Criterios de aceptación

- [ ] El fallo a media lista del aviso tardío no enciende el aviso de vaciado remoto (test con el eje a `true`).
- [ ] Decidido y fijado qué hace el asentamiento cuando la medida falla.

## Medido en 2.1 (triage 2026-10-08)

- `performLateICloudWipe` llama a `cancelWipeGrace()` antes de borrar, pero su rama de fallo devuelve sin `settleSignalsAfterDeliberateWipe()`. El docblock de ese asentamiento dice que cancelar sin absorber no basta.
- `checkHasPersonalData` sigue devolviendo `true` en el `catch`, así que la absorción no se arma cuando la medida falla. Los seis llamadores de `settleSignalsAfterDeliberateWipe` no incluyen esta rama.

Triage 2026-10-08: abierto · low → low · `ContentView.performLateICloudWipe` sale por `guard failure == nil else { return failure }` sin `settleSignalsAfterDeliberateWipe()` (solo `cancelWipeGrace()` antes), y `checkHasPersonalData` sigue fallando a `true`.
