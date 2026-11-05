---
name: reference-propuestas-de-lola-en-la-mini
description: Las rutas ~/Claude/propuestas/… que citan las cards de Lola viven en la Mini; desde la Max se leen con `ssh mini`
metadata:
  type: reference
---

Las cards de Lola citan planes en `~/Claude/propuestas/marketing-lanzamiento/…`. Esa carpeta existe solo
en la Mini (`/Users/jur/…`); en la Max (`/Users/max-jur`) no está. Se lee con `ssh -o BatchMode=yes mini 'cat …'`.

**How to apply:** si una card apunta a una ruta local que no existe, prueba la otra máquina antes de
preguntar o de dar el plan por perdido. Y mide el plan contra el encargo: el 2026-11-04 la card pedía
/pt, 20 piezas y la URL de ASC, el encargo solo lo básico; Jürgen confirmó lo básico.
