---
name: neutro-durable-solo-grupos
description: Paso 5 del rediseño — una sesión solo-grupos ya no baja el iCloud del teléfono. PR #134; la mitad 2 la paró Jürgen con lo medido, y la review cazó 12 defectos míos, dos graves.
metadata:
  type: project
---

El bug del ADR §2-3: entrabas por «Vengo por un grupo», reabrías la app y el store personal adjuntaba el
espejo de iCloud y bajaba los datos del Apple ID. Cerrado con una marca propia que arman las dos altas
solo-grupos y que **no caduca** con `hasShownWelcomeChooser`.

**Why:** es el paso 5 de la cola del rediseño de sesiones y el que más cerca estuvo de romper el camino
contrario (el restore).

**How to apply:**

- **Device-QA PENDIENTE y NO simulable**, como los pasos 3, 4 y la reversa: sin cuenta de iCloud no hay
  espejo que adjuntar, así que la importación es inobservable en simulador. El guion está dentro del
  ticket en `qa/`, y su punto que más caro sale es el **recorrido 3** (la no-regresión: restaurar de
  iCloud tiene que seguir funcionando).
- **La mitad 2 la paró Jürgen y eligió «entrega la mitad 1»** (2026-09-10, en vivo). Lo medido que la
  bloqueó: el desmontaje en caliente lo rechaza `PersonalSwapReleaseLogic.mountAdmitsSwap` cuando el
  mount de salida lleva mirror, y `wipeAllUserData` borra POR FILAS ⇒ con el espejo montado **exporta los
  deletes a iCloud** y destruye el corpus que el criterio promete conservar. Ticket propio, y **conviene
  decidirlo junto a `late-icloud-wipe-can-re-export-between-its-two-halves`**: los dos convergen en el
  mismo mecanismo (borrar archivos pre-mount con `armSignOutWipe` en vez de filas), y su precio es el
  relanzamiento que Jürgen quería evitar.
- **También decidió: sin migración para el parque instalado.** Quien ya hizo el alta se cura al
  reinstalar. Armar retroactivamente alcanzaría a los restaurados.
- **La puerta «datos ajenos» NO se retiró**, contra lo que pedía el ticket: sin la vuelta al neutro,
  retirarla deja al usuario creando un grupo encima de datos ajenos. Se va con la mitad 2.
- Deja además `groups-only-private-restart-skips-the-wipe-alert` (**high**), una regresión que encontró la
  review: desde solo-grupos, «Primera vez → privado» se salta el aviso de datos existentes. Mitigada para
  que no persista entre arranques; abierta dentro de la misma sesión.

**El dato de calibración: la review adversarial (3 lentes) cazó 12 defectos y los 12 eran míos**, con 14
tests verdes y tres mutantes ya caídos antes de correrla. Los dos graves fueron el desarme sin guard de
secundaria —que le devolvía el espejo al dueño desde la sesión de otra persona— y la marca sin confinar al
modo, que revivía tras la reversa y apagaba el espejo para siempre. Y el bloqueante de tests: el adaptador
de producción, único cable que enciende la feature, no lo miraba nadie.
