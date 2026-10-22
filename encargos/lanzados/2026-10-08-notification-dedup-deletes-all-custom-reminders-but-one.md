---
esfuerzo: high
---
# Al abrir la app Yala deja de borrar los recordatorios propios: la limpieza de avisos duplicados del arranque solo junta los avisos de sistema

## Contexto
Card del tablero `tablero-al-abrir-la-app-se-borran-todos-los-reco-rk9e` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/notification-dedup-deletes-all-custom-reminders-but-one.md` (hallazgo al margen de la review adversarial de `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`, 2026-09-24). El triage de Frank del 2026-10-07 lo confirmó vivo en el código de 2.1.

Lo que le pasa al usuario: crea tres recordatorios propios y un día, al abrir Yala, solo queda uno. Es pérdida de datos de la persona, en cada arranque.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- `NotificationService.deduplicateNotifications` (`Yala/Services/NotificationService.swift`, la función empieza hacia la L593 en 2.1 de hoy) agrupa TODOS los `NotificationItem` por `typeRaw` y borra todos menos el primero del grupo (el activo primero).
- Los recordatorios de la persona tienen `typeRaw == "custom"` (default del modelo), así que caen todos en el mismo grupo.
- Corre en cada arranque (`AppBootstrapper`, paso 6.1) detrás del gate de quiescencia del import de iCloud. Su motivo legítimo, según su propio comentario (R9), es que CloudKit puede entregar avisos de sistema sincronizados entre el fetch y el save del onboarding: los tipos de sistema se siembran por dispositivo.
- Sin medir: si la UI permite hoy crear varios avisos `custom` (si solo existe uno, el bug no se ve). Es lo primero que hay que comprobar en la pantalla de avisos.

Esta es la primera de la cola de cards de Yala del 2026-10-08. No hay otra sesión Yala viva. Acaba de cerrar `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration`: su PR #397 está en auto-merge a 2.1 con los tests de CI en curso; toca el borrado de iCloud pendiente, no los avisos.

Para orientarte: `CLAUDE.md`, `.claude/rules/swiftdata-cloudkit.md`, `.claude/rules/testing.md` y el ticket.

## Que se pide
1. Medir en la pantalla de avisos (simulador, con la semilla de UI tests) si se pueden crear varios avisos `custom`. Anótalo en el ticket.
2. Reproducir con test unitario: tres `custom` distintos más un tipo de sistema duplicado → tras la limpieza hoy queda un solo `custom`.
3. Arreglar con la opción más robusta: la limpieza solo agrupa los tipos de sistema (los que se siembran por dispositivo) y nunca los `custom`. Si de verdad pueden llegar duplicados idénticos de un `custom` (la misma fila por dos caminos), se deduplican por su identidad, nunca por tipo. Decídelo con evidencia del código, no por suposición.
4. Mira si borrar un `NotificationItem` cancela o deja huérfana su notificación local programada, y que el arreglo no deje avisos programados sin fila ni filas sin aviso.
5. Recordatorios ya borrados: investiga si se pueden recuperar (por ejemplo, si siguen en la nube). Si no se puede, déjalo escrito en el ticket. No inventes una cura que reescriba datos de la persona.
6. Test: la tabla pura de qué se agrupa (sistema duplicado, varios `custom`, mezcla) y un control que salga rojo con el código viejo.
7. Anota lo medido en el ticket y muévelo según las convenciones del repo.
8. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-al-abrir-la-app-se-borran-todos-los-reco-rk9e` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- La siembra de los avisos de sistema y el gate de quiescencia del import (`isImportQuiescent`).
- El flujo de crear y editar recordatorios, salvo lo necesario para el arreglo.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion. Lo que toque datos de la persona (borrar o reescribir importes sin respuesta suya) es de alto riesgo: no se hace sin decisión.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~29 GB libres el 2026-10-08 a las 07:45, por debajo del umbral de 32).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR de `late-icloud-wipe-stays-frozen-after-a-settled-failed-migration` sigue en CI (si el orden de lanzamiento cambió, el del encargo lanzado justo antes que este). Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Con varios recordatorios propios, abrir la app no borra ninguno; los avisos de sistema duplicados se siguen limpiando.
- Tabla pura de la limpieza y control rojo con el código viejo.
- Builds `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, ticket con lo medido (cuántos `custom` permite la UI, si lo borrado se puede recuperar), card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Decisiones resueltas antes de tocar código (sesión del 2026-10-08, de día; ninguna pide a Jürgen):

1. **Qué junta la limpieza: todo lo que no es `custom`, nunca los `custom`.** Es el mismo criterio que ya usa la clave de
   fusión del linaje (`LineageTwinKey.notificationFusion`: `custom` → sin clave). Un `typeRaw` desconocido (un tipo de
   sistema de un build más nuevo) se sigue juntando: también se siembra por dispositivo.
2. **Los `custom` NO se deduplican por identidad.** Medido en el código: un `custom` solo nace en
   `NotificationEditorSheet` (un insert por guardado) y el espejo da un record por fila; ningún camino crea dos filas de
   la misma persona. Juntar por `id` sería peligroso: el colapso de UUID por default de CloudKit (el que repara
   `repairCollapsedIdentityUUIDs` en otros modelos) daría el mismo `id` a dos recordatorios distintos, y la limpieza
   volvería a borrar uno.
3. **Lo que la limpieza borra se desprograma** tras un `save()` con éxito, con los mismos identificadores que
   `cancelNotification` (el del item y los siete por día de la semana). Hoy borra la fila y deja su aviso repetitivo vivo
   hasta que alguien abra Ajustes › Notificaciones.
4. **Recuperar lo ya borrado: no se construye cura.** Se documenta en el ticket qué rastro queda y por qué no se usa.
5. **Pruebas**: tabla pura de qué se junta, integración contra `deduplicateNotifications` con un store en memoria
   (rojo con el código viejo), los identificadores que desprograma, y un XCUITest que crea tres recordatorios,
   relanza y los cuenta (mide además cuántos permite la UI).
6. **Device-QA**: no queda; la card va a «done» asignada a frank.
