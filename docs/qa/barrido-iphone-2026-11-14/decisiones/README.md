# Decisiones del barrido del iPhone (14-nov-2026)

Las tres decisiones que el barrido dejó a Jürgen —fila de chips en el iPhone SE, dominio del conector de Claude en
producción y las siete de la mascota Yalitto— con opciones, recomendada y selector.

- **Artifact:** https://claude.ai/artifact/Jd1oX9jTnuj8HxPofbTQzh. Las respuestas se guardan en su db, colección
  `respuestas`, un documento por decisión (`chips`, `dominio`, `m1`…`m7`) con `opcion` y `nota`.
- **Regenerar:** `cd fuente && python3 build.py` (Python 3 de serie). Usa los personajes de
  `docs/ux/mascota-yalitto-2.3/fuente/yalittos.py`. Se republica con la herramienta Artifact sobre `decisiones.html`.
- **Capturas:** `capturas/se-*.jpg` son reales (iPhone SE 3.ª gen., simulador iOS 27.2, Yala Dev de 2.3 del 14-nov,
  semilla `minimal`). `capturas/maqueta-*.jpg` son maquetas hechas con recortes de esas capturas; no hay código nuevo.
