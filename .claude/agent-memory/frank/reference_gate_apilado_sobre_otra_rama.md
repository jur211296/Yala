---
name: gate-apilado-sobre-otra-rama
description: Encargo con depende: y la rama base aún en cola — apilar con reset --keep y elegir interfaz con --base de esa rama
metadata:
  type: reference
---

Encargo con `depende:` cuyo PR aún no entró en 2.3 (25-nov, lote 4 sobre el lote 3 de la Bandeja): la rama se apila con
`git reset --keep origin/<rama-de-la-que-depende>` antes del primer cambio, y al mergear el de abajo se rebasa.

**Why:** los dos tocaban `InboxViewModel`; partir de 2.3 era conflicto seguro. Y los selectores del gate miran contra
`origin/2.3`: `interfaz-de-lo-tocado.py` sin `--base` metía las clases del lote de abajo (ya pasadas en su gate).

**How to apply:** `interfaz-de-lo-tocado.py --base origin/<rama-de-abajo>`; al revisor de checklist, decirle que su
alcance es `git diff origin/<rama-de-abajo>`. El PR se abre contra 2.3 y dice en la primera línea que va apilado.
