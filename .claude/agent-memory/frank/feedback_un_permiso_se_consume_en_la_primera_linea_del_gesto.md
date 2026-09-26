---
name: un-permiso-se-consume-en-la-primera-linea-del-gesto
description: Un «sí» de un solo uso (aceptar perder datos) se retira al EMPEZAR el gesto que lo usa, no en el paso que lo lee — las salidas tempranas lo dejaban vivo para otro gesto.
metadata:
  type: feedback
---

Un permiso de un uso que abre una pérdida —aquí, «Perderlos y empezar de cero»— se toma y se retira en la
**primera línea** del gesto que lo va a usar, antes del primer `await`, y viaja por parámetro hasta quien lo lee.

**Why:** 2026-09-26, PR #265. Lo consumía la subida (`drainGroupsBeforeFreshStart`), pero el borrado sale antes por
la espera del import (`importNotQuiescent`, `cancelled`), y el «sí» quedaba en el singleton: otro gesto por otra
pantalla, minutos después, perdía cambios sin enseñar el aviso. Lo cazaron DOS lentes de la review por separado; los
mutantes no, porque ninguno probaba una salida temprana. El mismo día, el paso del Welcome que borra al montarse
necesitó lo mismo: un permiso de un uso que da el tap que confirmó.

**How to apply:** al escribir «vale para un intento», enumera las salidas del gesto ANTES del punto de consumo. Si
hay alguna, mueve el consumo arriba. Relacionado: [[una-ventana-dura-lo-que-su-reintento]],
[[una-marca-que-abre-una-entrada-se-ata-a-quien-la-gano]].
