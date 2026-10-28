---
id: retrying-a-group-creation-after-a-lost-response-creates-a-second-group
status: backlog
priority: low
area: groups
created: 2026-10-24
updated: 2026-10-24
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
