---
id: prefs-pull-overwrites-a-pending-local-change-on-screen
status: backlog
priority: low
area: "modo-nube, sync, preferencias"
created: 2026-09-26
updated: 2026-10-08
source: "Paso 0 de `prefs-push-purge-drops-a-change-made-during-the-upload` (2026-09-26); previo a ese diff"
---

# Una preferencia que aún no ha subido vuelve un momento al valor de la nube

## El problema, en lenguaje de usuario

Cambias una preferencia y, antes de que Yala consiga subirla, la sincronización baja lo que hay en la nube. La pantalla
vuelve al valor anterior. En el ciclo siguiente tu cambio sube y reaparece. No se pierde, pero lo ves deshacerse un rato.

## Por qué pasa (leído el 2026-09-26; sin ejecutar en device)

- `CloudSyncRuntime.syncPrefsOnce` hace push y luego pull en el mismo ciclo. El pull llama a
  `PreferenceSyncService.applyPulledPrefs`, y `PreferenceMergeLogic.decide` aplica el remoto sin mirar el outbox: no
  sabe que hay una entry pendiente para esa key con un HLC más nuevo.
- Dos caminos llegan ahí:
  1. **El push falla transitorio** (`.transient`, o un resultado con `reason`): la entry se queda, el pull baja el valor
     viejo y lo pinta.
  2. **La carrera del ticket hermano**: tras su arreglo, el cambio hecho durante el push se queda en la cola, pero el
     pull del mismo ciclo trae el valor que acaba de subir (el primero) y lo pinta un ciclo.
- Antes del arreglo hermano el camino 2 era peor: la pantalla se quedaba con el valor viejo para siempre.

## Criterios de aceptación

- [ ] El merge del pull no aplica un valor remoto sobre una key con entry pendiente del mismo owner cuyo HLC es más nuevo
  que el del `PulledPref`. Con el remoto más nuevo (otro dispositivo), se aplica como hoy y la pendiente acaba `noop`.
- [ ] Test de los dos caminos (push transitorio y cambio durante el push) y control con el remoto más nuevo.

## Notas

- La comparación tiene que usar el mismo orden que el LWW del servidor (HLC c1), o el cliente decidirá distinto que él.
- El drenaje iKV→outbox encola con HLC fresco sin escribir local: revisar que el filtro no deje la pantalla con un valor
  que no es ni el local ni el remoto.

## Medido en 2.1 (triage 2026-10-08)

- `CloudSyncRuntime.syncPrefsOnce` sigue haciendo push (purga solo resultados sin `reason`) y pull en el mismo ciclo; `PreferenceSyncService.applyPulledPrefs` llama a `PreferenceMergeLogic.decide(key:remote:local:)`, que no recibe ni consulta el outbox.
- 099aa010a (el arreglo hermano) solo cambió la purga por HLC; el pull no se tocó.

Triage 2026-10-08: abierto · low → low · parpadeo de un ciclo sin pérdida: el cambio sube y reaparece en el siguiente.
