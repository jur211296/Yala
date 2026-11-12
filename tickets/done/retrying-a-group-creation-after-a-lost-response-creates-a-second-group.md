---
id: retrying-a-group-creation-after-a-lost-response-creates-a-second-group
status: done
priority: low
area: groups
created: 2026-10-24
updated: 2026-10-28
source: "lote 12.1 Grupos (card 5d22), lo que el arreglo no cubre"
---

# Si crear un grupo falla tras guardarse en el servidor y se reintenta, salen dos grupos

## Qué pasa

`create_group` es server-first y cada toque de «Crear» acuña una zona nueva. Si el servidor guarda el grupo y la
respuesta se pierde (sin red a la vuelta, un 5xx del gateway tras el commit), la persona ve el error y vuelve a tocar
«Crear»: el segundo toque crea OTRO grupo con el mismo nombre. Desde la card 5d22 el primero baja con el pull y quien lo
creó ya aparece como dueño de los dos.

## Por dónde va

Reusar la zona del intento pendiente (`PendingGroupCreationStore`) al reintentar con el mismo formulario: el servidor
contesta `yala_group_exists` si ya lo guardó, y eso se puede leer como éxito. Decisión de diseño: qué pasa si la persona
cambió el nombre entre el primer toque y el segundo.

## Hecho (2026-10-28, card y1ru)

`PendingGroupCreationStore` guarda el nombre del intento. Un reintento de «Crear» con el mismo nombre (recortado como el
servidor) y la misma sesión reusa la zona del intento pendiente; si el servidor contesta `yala_group_exists`, es el grupo
del toque anterior y se materializa como un éxito. **Decisión tomada:** con el nombre cambiado entre toques se acuña una
zona nueva (comportamiento de antes); el intento del primer toque se queda para que el pull lo adopte si se guardó. Una
zona recién acuñada que recibe `yala_group_exists` sigue siendo error. Tests: `GroupCreateLostResponseTests` (§ y1ru).

Review adversarial (2026-10-28): un rechazo claro del reintento con la zona reusada ya no borra el apunte del primer toque.
Residual aceptado: si entre toques cambia la divisa, el icono o el color y el primero se guardó, gana lo del primero (el pull
trae la meta del servidor).
