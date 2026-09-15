---
name: una-frase-de-alcance-se-cuenta-por-llamadores
description: «Solo le llega en carrera», «le llega poco» — una frase de alcance se mide enumerando TODOS los llamadores del cliente, no leyendo el camino principal; el 15-sep dos lentes la tumbaron por dos vías que no miré
metadata:
  type: feedback
---

**Antes de escribir que un caso «solo llega» por un sitio, cuenta los llamadores del cliente que lo produce.** Leer el
camino principal y deducir el resto es como se escribe una frase falsa con cara de medida.

**Why:** el 2026-09-15, en `groups-sync-reads-a-missing-attest-401-as-a-session-expiry`, escribí en un ticket hermano,
en `.claude/rules/gateway-attest.md` y en el Paso 0 que el canal personal solo veía el 401 de attest «en carrera»,
porque `CloudSyncRuntime.performCycle` pide el attest antes de subir. Dos lentes la refutaron por dos vías que yo no
había mirado: la migración (`MigrationWorkExecutor`, `MigrationSnapshotUploader`) llama a `SyncPushClient.push` directo,
sin esa puerta; y la puerta solo lee la caché local, así que un token que el servidor ya rechaza la pasa. La frase ya
estaba en tres documentos cuando llegó la review.

**How to apply:**

- Una frase de alcance («solo», «nunca», «le llega poco», «en carrera») es una afirmación verificable: grep de los
  call-sites del método que produce el caso, no del flujo que tengo en la cabeza.
- Una puerta que «comprueba X antes» comprueba lo que lee: si lee una caché, no protege de lo que el servidor ya cambió.
- Si no lo he contado, escribo «sin medir». El ticket de origen decía justo eso, y yo lo sustituí por una inferencia.

Relacionado: [[mi-docblock-tambien-es-una-premisa]], [[la-premisa-del-encargo-tambien-se-mide]].
