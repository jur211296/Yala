---
name: sellar-en-la-buena-noticia-cobra-la-app-cerrada
description: Un reloj de techo sellado en una respuesta BUENA cuenta como espera los días con la app cerrada; el primer poll sin red al volver saca con un texto falso. Se sella en la primera observación que no avanza.
metadata:
  type: feedback
---

**Un reloj de «sin avanzar» se BORRA con la buena noticia y se SELLA con la primera observación mala, no al revés.**

**Why:** el 2026-09-23, en la espera del seguidor (`waitingForLeader`), sellé el reloj al entrar en la fase y en cada
`claiming_in_progress` creyendo que así «el tiempo con la app cerrada cuenta, como en el resto de pasos». No era como el
resto: allí sella la primera observación parada. Y el seguidor es justo quien cierra la app mientras espera: al volver días
después sin red, un solo poll lo sacaba con «lleva días sin avanzar» aunque el líder hubiera terminado. Lo cazaron dos
lentes; el mutante que lo reintroduce (M17) ahora muere.

**How to apply:** al copiar un techo a una fase nueva, pregunta en qué instante sella el molde y quién suele cerrar la app
en esa fase. Si mi docblock dice «como en el resto», compruébalo en el código del resto. Relacionado:
[[un-reinicio-se-mide-contra-su-cadencia]], [[mi-docblock-tambien-es-una-premisa]].
