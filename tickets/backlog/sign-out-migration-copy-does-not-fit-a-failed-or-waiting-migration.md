---
id: sign-out-migration-copy-does-not-fit-a-failed-or-waiting-migration
status: backlog
priority: low
area: "sesiones, modo-nube"
created: 2026-09-27
updated: 2026-09-27
source: "review adversarial de `private-sign-out-proceeds-with-a-migration-in-flight` (2026-09-27)"
---

# El aviso de «el paso de tus datos no terminó» no encaja con una migración fallida o esperando a otro dispositivo

## El problema, en lenguaje de usuario

Al cerrar sesión con la migración fuera de reposo sale «El paso de tus datos entre iCloud y la nube todavía no terminó, y
cerrar sesión ahora podría borrar lo que falta por subir… termínalo desde ahí (si falló, toca «Reintentar»)». Tres estados
en los que no es exacto:

- **Fallida** (`failedRollback`): el rollback ya devolvió todo y no se sube nada; «podría borrar lo que falta por subir» no es
  el porqué. Y «Reintentar» solo resetea, pero suena a volver a migrar.
- **Esperando a otro dispositivo** (`waitingForLeader`): no se puede «terminar» desde aquí; lo que hay es «Dejar de esperar».
- **Controller trabajando con `uiState` en `.idle`** (preflight, adopt del Welcome, consent): la fila «Dónde viven tus datos»
  puede no verse con el kill de la nube como está en producción. Transitorio.

## Criterios de aceptación

- [ ] Texto por estado (o uno que no afirme la causa), en los 16 idiomas. Se decide junto con
  `apple-id-change-check-stays-off-after-a-failed-migration`: si se abre el cierre tras un fallo, la primera mitad desaparece.
