---
name: banco-yaml-en-ci-tiene-pyyaml
description: Un banco de qa/scripts que lee YAML pasa en la Mac (sin PyYAML, cae a Ruby) y cae en el CI (ubuntu trae PyYAML); se prueba con un venv
metadata:
  type: reference
---

En la Mini y la Max no hay PyYAML: los scripts que leen YAML caen a `ruby -ryaml`. El runner ubuntu del CI
sí lo trae, así que el camino de PyYAML solo se ejecuta allí. El 19-nov, `checklist-elegir-test.sh`
salía verde en `gate-ci-checks` local y rojo en `coverage-index` desde el 17-nov: `yaml.safe_load` lanzaba
sin control ante un YAML roto y el PR llevaba dos días atascado sin que nadie lo viera en local.

**Cómo probar los dos caminos:** `python3 -m venv <scratchpad>/venv && <scratchpad>/venv/bin/pip install pyyaml`,
y correr el banco con `PATH=<scratchpad>/venv/bin:$PATH` (el `python3 -I` del script sigue usando el
site-packages del venv). Luego otra vez sin el `PATH`, para el camino de Ruby.

Relacionado: [[mergear-a-mano-mira-todos-los-checks]].
