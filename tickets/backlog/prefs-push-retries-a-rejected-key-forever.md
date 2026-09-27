---
id: prefs-push-retries-a-rejected-key-forever
status: backlog
priority: low
area: "modo-nube, sync, preferencias"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `prefs-push-purge-drops-a-change-made-during-the-upload` (2026-09-26), lente de carreras; previo a ese diff"
---

# Una preferencia que el servidor rechaza para siempre se reintenta en cada ciclo

## El problema, en lenguaje de usuario

Si el servidor no acepta nunca un cambio de preferencia concreto, Yala lo vuelve a mandar en cada sincronización, sin fin
y sin avisar. Y como el pull del mismo ciclo pinta el valor del servidor, en pantalla el cambio parece deshecho.

## Por qué pasa (leído el 2026-09-26; el rechazo permanente, inferido)

- `gateway/src/sync/routes.ts` responde `status: "noop", reason: "upstream_<status>"` con **cualquier** fallo del RPC
  `apply_pref`, también un 4xx; y `reason: "malformed"` si la entry llega mal formada.
- `CloudSyncRuntime.syncPrefsOnce` solo purga resultados sin `reason`, así que esa entry se queda y viaja en cada ciclo.
  No hay tope, ni dead-letter como en el outbox del dominio (`rejectedReason`), ni rastro.
- **Inferido, sin medir:** que `apply_pref` devuelva un 4xx permanente. El RPC no está en el repo; un candidato es un HLC
  que el servidor considere demasiado adelantado (desde `personal-clock-rollback-wedges-the-drain-forever`, `enqueue`
  estampa por encima del último emitido aunque esté lejos del reloj real).

## Criterios de aceptación

- [ ] Medir qué rechazos de `apply_pref` son permanentes (leer el RPC en staging).
- [ ] Si hay alguno: distinguir `upstream_4xx` de `upstream_5xx` y darle a la entry rechazada para siempre una salida
  (dead-letter con rastro), con test.
