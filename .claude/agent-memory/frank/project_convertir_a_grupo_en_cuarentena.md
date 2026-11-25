---
name: convertir-a-grupo-en-cuarentena
description: Los dos casos de PersonalToGroupConversionUITests están en cuarentena desde el 25-nov hasta el 9-dic con un arreglo no comprobado contra el fallo del CI
metadata:
  type: project
---

`PersonalToGroupConversionUITests` (convertir y cancelar la revisión) entró en `qa/cuarentena.json` el 2026-11-25, dueño
frank, salida 2026-12-09.

**Why:** rojo 3/3 en las nocturnas del 22, 23 y 24-nov («El detalle no ofrece «Editar»»), pero en la Mini pasa siempre
(10/10 antes y después). El arreglo (llevar la fila del Bus a la franja central con arrastres cortos) sale de leer el
log del CI, no de verlo fallar: el CI no guarda vídeo de la UI.

**How to apply:** al revisar la lista de rojos o el 9-dic, mira las nocturnas desde el 26-nov. Tres verdes seguidas →
sacarla de la lista. Si vuelve el mismo rojo, el arreglo no era: pedir el `.xcresult` de esa tanda (o subirlo como
artefacto) antes de otra hipótesis. Relacionado: [[un-timeout-tapa-el-rojo-de-detras]].
