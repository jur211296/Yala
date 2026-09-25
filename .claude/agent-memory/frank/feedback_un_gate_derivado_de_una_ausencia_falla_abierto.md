---
name: un-gate-derivado-de-una-ausencia-falla-abierto
description: Un guardarraíl que autoriza porque NO encuentra la señal de peligro se abre justo cuando la señal falla — la marca tiene que ser POSITIVA. Medido el 2026-09-10 con el CloudMigrationMarker, y de paso: la mitad de un guard que parece un bug puede ser el único camino de convergencia de otro device.
metadata:
  type: feedback
---

**Cuando un gate autoriza una operación peligrosa, la señal que lo abre tiene que ser una afirmación
POSITIVA de algo que ocurrió, nunca la AUSENCIA de la señal de peligro.**

**Why:** el 2026-09-10, al abrir «Volver a iCloud» a las cuentas born-cloud, había que distinguirlas
del *migrado sin mapa* (a quien remontar el mirror le puede **resucitar** lo que borró: su zona CloudKit
sigue teniendo esos records). Escribí `hasEverMigrated = ¿existe el CloudMigrationMarker?` y abrí la
puerta cuando **no** estaba. La review adversarial lo tumbó con dos poblaciones reales:

- un **2.º dispositivo adoptado de una cuenta MIGRADA** puede no tener marcador — su propio belt lo dice,
  «ausente = no bloquea (solo diagnóstico)» —, y si el mirror no lo importó en el adopt ya no lo importará;
- un botón del panel DEBUG lo **borra** a propósito, para limpiar marcadores stale.

En los dos casos un migrado pasaba por born-cloud y se llevaba por delante el guardarraíl **justo para la
población que protege**. La versión final es una marca que escribe el alta (`isBornCloud`): si no está, se
exige el mapa como siempre. Falla CERRADO.

**How to apply:**

- La pregunta de diseño no es «¿esta señal distingue los dos casos?» sino **«¿qué pasa cuando la señal
  falta por error?»**. Si la respuesta es «autorizo», está mal, aunque distinga bien en el caso normal.
- **Enumera los borradores, no solo los escritores.** «Lo escribe el cutover y solo el cutover» era cierto
  y no bastaba: la *presencia* tiene más caminos que la *escritura* (llega por CloudKit en el adopt, la
  borran tres sitios). Un docblock que justifica un invariante citando al escritor único es media medición.
- **Falso negativo > falso positivo** cuando el falso positivo pierde datos. El precio aquí fue no
  mostrarle un botón a un born-cloud en su segundo teléfono; el pago, no resucitarle borrados a un migrado.
  Se acepta y se deja en ticket, no se disimula.
- Colgar la marca del escritor que ya existe es la tentación barata y suele mentir: `writeCloudArmed`
  parecía el sitio natural y **lo llama también el adopt**, que no es un alta.

## La otra mitad de la lección: la «puerta abierta» que cerré era un camino de convergencia

En el mismo cambio vi que una cuenta ya revertida podía reclamar la reversa **otra vez** (conserva
`migrated_at`, que `reverse_complete` no toca a propósito) y lo cerré como si fuera un bug. Lo era en
single-device. En multi-device era **el único camino** por el que el segundo teléfono del mismo usuario
—que sigue en modo nube, con el backend congelado— salía de ahí. Y como el cliente no tiene desatascador
para un rechazo, mi «arreglo» lo dejaba con la barra clavada al 15 % **para siempre**.

⇒ **Antes de cerrar una puerta que nadie parece usar, pregunta quién llega por ella con OTRO
dispositivo.** El estado que parece incoherente en un device suele ser el estado normal del segundo.

Relacionado: [[un-gate-falla-abierto-por-su-entrada]] (la misma familia, en la entrada en vez de en la
señal) · [[review-adversarial-caza-lo-mio]] · [[mi-docblock-tambien-es-una-premisa]]

## Un tercer caso, del 2026-09-11: el filtro de TIPO sobre el error

`iCloudSyncService` recibía `event.error as? CKError`. Un evento del espejo que TERMINABA con un error de
otro dominio (`NSCocoaErrorDomain` 1344xx) llegaba con `error == nil` y fecha de fin, y caía en la rama de
éxito: movía el ancla del export, y el cierre privado del paso 9 borraba lo que no estaba en iCloud. Es la
misma familia vista desde el error: **«no hay error» se leía como «fue bien»**, y un cast que filtra por
tipo fabrica justo esa ausencia. La marca positiva existía y nadie la leía: `Event.succeeded`.

⇒ Cuando una rama de éxito se decide por `error == nil`, busca una señal POSITIVA en el payload
(`succeeded`, un status, un 2xx) y úsala. Y desconfía de todo `as? TipoConcreto` sobre un error: lo que no
sea de ese tipo se vuelve invisible.

**Corolario, 2026-09-24 (PR #242, dos rondas de review):** lo mismo con un *casado*. Escribí «la clave de linaje se lee
y no casa con nada ⇒ aquí no hay gemela ⇒ sube». Tres lentes lo tumbaron: una clave que no casa puede ser la MISMA fila
(el `createdAt` que la migración ligera rellenó en cada teléfono, una categoría editada). **Casar prueba; no casar no
prueba nada.** La versión buena exime solo con una afirmación positiva (el historial dice «creada aquí después») y casa
solo con clave única en los dos lados. La segunda ronda cazó además que casar por un campo editable (el nombre) deja
que un renombrado cruce identidades: la clave de un casado tiene que ser inmutable, no solo legible.
