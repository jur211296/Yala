---
name: reponer-lo-guardado-resucita-lo-cancelado
description: Un «guardar al entrar, reponer al salir» repone también lo que el gesto nuevo SUSTITUYE; y lo que el llamador hacía tras el paso deja de correr si lo repuesto lanza.
metadata:
  type: feedback
---

Al copiar un molde de «guardar los pendientes al entrar y reponerlos al salir», **filtra lo que el gesto nuevo
sustituye**: no todo lo pendiente es «el estado de antes».

**Why:** el 2026-09-27 (#275) guardé todos los pendientes al tocar «Activar la nube». Un `.adoptBackendAccount`
pendiente también entraba, y «Cancelar» al 22 % lo reponía y lo ejecutaba en el acto, en el mismo save que
dejaba la marca `.cancelled`: el teléfono entraba en la cuenta que la persona acababa de dejar. Lo cazó la lente
de consumidores; mis 10 mutantes no, porque ninguno de mis tests sembraba un adopt. El código viejo lo
reemplazaba A PROPÓSITO (lo decían dos comentarios que no releí).

**How to apply:**
- Antes de guardar, enumera qué efectos pueden estar pendientes en el origen y pregunta por cada uno: ¿lo
  sustituye el gesto nuevo? Si sí, no se guarda. Busca los comentarios que justifican el reemplazo viejo.
- Una salida que REPONE y drena en el acto puede lanzar: lo que el llamador hacía DESPUÉS del paso (anotar un
  aviso, un testigo) va dentro del `mutate`, o no corre sin red.
Relacionado: [[una-parada-nueva-hereda-lo-que-el-camino-ya-hizo]], [[mi-arreglo-deja-el-mecanismo-sin-productor]].
