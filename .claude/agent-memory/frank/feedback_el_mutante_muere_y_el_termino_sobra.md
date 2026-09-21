---
name: el-mutante-muere-y-el-termino-sobra
description: Un término con 5 mutantes muertos puede seguir sobrando — lo que hay que medir es la POBLACIÓN de cada rama, y la suya era gente con datos
metadata:
  type: feedback
---

**Que los mutantes de un término mueran prueba que está testeado, no que deba existir. Antes de
añadir una rama, cuenta QUIÉN la alcanza.**

**Why:** el 2026-09-20 añadí `.notFound(conclusive:)` para cumplir al pie de la letra un criterio de
Jürgen —«confirmar cuando la búsqueda no asentó»— con la rama concluyente llamando directo al gesto
destructivo, razonando que «al usuario que estrena la app no hay que ponerle un diálogo de más».
Cablear `isConclusive` a `true` fijo mataba **5 casos**, así que parecía cubierto.

Lo que no había medido era la población. `settled == true` exige `hasCompletedFirstImport`
(`iCloudSyncService.swift:586`), que exige un `.importEvent` exitoso, que exige que CloudKit trajera
algo. Y si trajo algo y `hasAnyData` sigue en `false`, lo que trajo son presupuestos o grupos, que ese
predicado no cuenta (`:773-775`). ⇒ **la rama «concluyente» tenía una sola población y era gente con
datos**, a la que mi `if` le daba el borrado de un toque. El usuario nuevo, que era a quien creía
estar protegiendo de la fricción, **nunca** pasaba por ahí: su búsqueda no asienta jamás.

La rama sobraba. `.notFound` confirma siempre, «cuando no asentó» y «siempre» eran el MISMO
comportamiento, y el hueco de `hasAnyData` salió en ticket propio.

**How to apply:**

- Ante una rama nueva, escribe la frase: **«esta rama la alcanza quien…»**, y derívala del código,
  no de la intención. Si no puedes nombrar a nadie, sobra; si nombras justo a quien pretendías
  proteger, está invertida.
- Un criterio del ticket escrito como condición (`cuando X`) **no obliga a que X sea un término del
  código**. Mide X primero: si resulta constante en toda la población real, el código sin condición
  cumple el criterio y no tiene agujero.
- Este es el hermano de [[el-mutante-que-sobrevive-puede-sobrar]] por el otro lado: allí el mutante
  vive y falta decidir entre test y código; aquí el mutante MUERE y el término sobra igual.
  Relacionado: [[el-predicado-del-ticket-no-es-el-criterio]], [[mi-arreglo-abre-un-camino-inalcanzable]].
