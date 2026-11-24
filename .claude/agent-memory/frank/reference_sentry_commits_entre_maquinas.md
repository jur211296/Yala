---
name: sentry-commits-entre-maquinas
description: Archivar en una máquina distinta de la build anterior hace fallar set-commits de Sentry (la release previa apunta a un commit local de la otra); los dSYM sí suben
metadata:
  type: reference
---

Medido el 2026-11-24 con la 2.3 (8), archivada en la Mini tras una 2.3 (7) archivada en la Max.

- El post-action del archivado sube los 3 dSYM sin problema, pero `set-commits --local` falla: «Could not find the SHA of
  the previous release». Con `--ignore-missing` tampoco: «object not found», porque la release anterior quedó atada a un
  commit que solo existía en el árbol de archivado de la Max (base + PR en cola, sin push).
- No bloquea nada: la simbolización depende de los dSYM, no de los commits. Se anota en «Encontrado» y se sigue.

**How to apply:** si vuelve a salir, no lo persigas en la subida. Si algún día importa la lista de commits por release,
archiva sobre un commit empujado (o crea la release con `--initial-depth`). Relacionado: [[reference-sentry-tokens-y-api]].
