---
id: notification-dedup-deletes-all-custom-reminders-but-one
status: done
priority: medium
area: "notificaciones"
created: 2026-09-24
updated: 2026-10-08
source: "review adversarial de `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), hallazgo al margen"
---

# El deduplicador de avisos borra todos los recordatorios personalizados menos uno

## El problema, en lenguaje de usuario

Creo tres recordatorios propios. Un día, al abrir Yala, solo queda uno.

## Lo medido (2026-10-08)

- **La pantalla deja crear tantos recordatorios propios como quieras.** Medido en el simulador (iPhone 17 Pro, iOS 27.0,
  `Yala Dev`, seed `minimal`) con el XCUITest nuevo: el «+» de Ajustes › Notificaciones creó «QA Uno», «QA Dos» y
  «QA Tres» y los tres salieron en la lista. En el código no hay tope: el botón siempre abre el editor y cada guardado
  inserta un `NotificationItem` de tipo `custom`.
- **El bug era real y salía en el primer relanzamiento.** Con el código de `2.1` (antes del arreglo), el mismo test
  relanzó la app sobre el mismo store y solo quedó «QA Uno»: `Al abrir la app se borraron recordatorios propios:
  ["QA Dos", "QA Tres"]`. El test unitario con tres `custom` y un `endOfDay` duplicado dejó un solo `custom`. Capturas:
  `~/Claude/worktrees/_capturas/2026-10-08-notification-dedup-deletes-all-custom-reminders-but-one/` (`antes.png`:
  solo «QA Uno» tras relanzar; `despues.png`: los tres).
- **La causa**: `NotificationService.deduplicateNotifications` (paso 6.1 del arranque, tras la quiescencia del import)
  agrupaba todos los avisos por `typeRaw` y borraba todos menos uno por grupo. Los recordatorios propios comparten
  `typeRaw == "custom"`.
- **Lo borrado no se desprogramaba.** La limpieza hacía `context.delete` sin quitar los avisos programados en iOS. El
  recordatorio desaparecía de la lista y seguía sonando cada día (repetitivo, con un aviso por día de la semana si
  tenía días elegidos), sin forma de apagarlo, hasta que la persona abría Ajustes › Notificaciones: esa pantalla llama
  a `rescheduleAllNotifications`, que quita todo lo pendiente y reprograma lo que hay. El chequeo del arranque
  (`ensureNotificationsScheduled`) no lo limpiaba: solo reprograma si hay MENOS pendientes que filas activas, y los
  huérfanos suman.
- **Ningún camino crea dos filas del mismo recordatorio propio.** Un `custom` solo nace en `NotificationEditorSheet`
  (un insert por guardado) y el espejo de CloudKit da un record por fila. Por eso no se deduplican por identidad: dos
  filas con el mismo `id` serían el colapso del UUID por defecto que CloudKit puede dejar en un record sin el campo, o
  sea dos recordatorios distintos.

## El arreglo

- La limpieza junta solo lo que no es `custom` (`NotificationDeduplicationLogic.groupKey`): los siete tipos de sistema
  y cualquier tipo que este build no conozca (solo puede ser uno de sistema de un build más nuevo). Es el mismo
  criterio que la clave de fusión del linaje (`LineageTwinKey.notificationFusion`), y un test los compara.
- Lo que borra lo desprograma después de guardar, con los mismos identificadores que `cancelNotification`
  (`NotificationService.scheduledRequestIdentifiers`).
- Pruebas: `NotificationDeduplicationStoreTests` (contra el store, rojo con el código viejo), `NotificationDeduplicationLogicTests`
  (la tabla, el control del agrupado viejo y la paridad con el linaje) y
  `NotificationsSettingsUITests#test_threeCustomReminders_surviveARelaunch`.

## Lo ya borrado: no se puede recuperar en general

- **La nube no lo guarda.** `NotificationItem` viaja por el espejo de CloudKit (modo iCloud) y por el canal de la nube
  (`CloudSyncEngine.personalEntityNames`). El borrado de la limpieza viajó por los dos como un borrado normal: CloudKit
  lo quita del iCloud de la persona y del resto de sus dispositivos. En modo nube el backend recibe un tombstone; si
  conserva las columnas de la fila borrada no está medido (el cuerpo de `apply_delta` no vive en el repo), y la
  población en modo nube era casi nula.
- **El único rastro es el aviso huérfano** que sigue programado en iOS: título (el nombre), texto, hora y días. No
  guarda icono, color ni si estaba activo, no existe para los recordatorios que estaban apagados, y desaparece en
  cuanto la persona abre Ajustes › Notificaciones (que es lo primero que hace quien echa de menos uno).
- **No se construye cura**: reconstruir filas a partir de esos avisos crearía datos sin que la persona lo pida y solo
  alcanzaría a una parte. Si se quisiera, sería un ticket propio con decisión de Jürgen.

## Residuales (review adversarial del 2026-10-08, severidad baja)

- **El desprogramado solo ocurre en el dispositivo que limpia.** Si el dispositivo A borra la copia de un aviso de
  sistema que venía de B, a B le llega el borrado por el espejo y su aviso local de esa fila sigue programado hasta que
  abra Ajustes › Notificaciones. Es el mismo trato que tiene cualquier borrado remoto de un recordatorio: nadie
  desprograma al recibir un borrado. Igual con los recordatorios que la limpieza vieja ya borró: siguen sonando hasta esa
  pantalla.
- **Si el `save()` de la limpieza falla**, los borrados quedan pendientes en el contexto (sin rollback, como antes) y los
  guarda el siguiente save del arranque, pero sus avisos no se desprograman.
- Descartado: que dos filas con el mismo `id` hicieran desprogramar al superviviente. El campo `id` existe desde el
  commit que creó el modelo, así que CloudKit siempre lo trae, y con ids repetidos la programación ya se pisaba antes.

## Criterios de aceptación

- [x] Medido si la UI permite más de un aviso `custom` (sí, sin tope).
- [x] El deduplicador no agrupa los `custom` (solo los tipos de sistema, que se siembran por dispositivo).
- [x] Lo que borra se desprograma.
- [x] Documentado si lo borrado se puede recuperar (no, salvo el rastro parcial del aviso huérfano).
