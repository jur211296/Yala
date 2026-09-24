---
name: la-huella-se-ata-al-que-entra
description: Un sello que se escribe al contestar «ya existe» tiene que mirar si quien llama ENTRA o solo choca — la misma respuesta la reciben los dos
metadata:
  type: feedback
---

Un sello de servidor que marca «otro dispositivo entró» se ata al **verbo que entra**, no a la **respuesta** que lo
acompaña. El 2026-09-24 (g16_02) sellé en la rama `existing_stable` de `claim_account` para cualquier claim personal
de otro dispositivo, y la lente de cliente cazó que «Activar Yala completo» desde un segundo teléfono recibe esa misma
respuesta y **se queda fuera**: el sello bloqueaba a los dos teléfonos sobre una cuenta vacía. Toda entrada real acaba
en el claim del adopt (`migration: true`); el sello pasó a exigirlo.

**Why:** una respuesta del servidor la comparten llamadores con destinos distintos (entra / bloquea / reintenta). Si el
efecto nuevo se escribe al responder, hereda a todos, también a los que no hacen lo que el efecto afirma. Es la familia
de [[el-outcome-que-clasifico-lo-produce-otro]] vista desde el servidor.

**How to apply:** antes de añadir un efecto a una rama de respuesta, enumera QUIÉN recibe esa respuesta y qué hace
después en el cliente (grep de los llamadores del endpoint y de cada `case` del outcome). Si alguno no hace lo que el
efecto dice, el efecto necesita un término que lo distinga (aquí `p_migration`), y ese término lleva su escenario en la
sonda (el 16) y su mutante (M5). Y un candado «por si acaso» que no cambia ningún desenlace posible se quita
([[prefiere-lo-limpio-a-lo-defensivo]]): la misma review retiró mi `for update`.
