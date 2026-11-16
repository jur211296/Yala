---
toca: .github/, qa/, scripts/, docs/
release: no
---
Yala
# Terminar el merge de 2.2 en 2.3: el chequeo de firmas ignora lo que ya está en 2.2

Pedido de Jürgen, 10-nov 6:03 Lima. El [PR del merge de 2.2 en 2.3](https://github.com/jur211296/Yala/pull/879) (rama `encargo/2026-11-09-merge-2-2-en-2-3`) tiene todo verde salvo el job `coverage-index` de `.github/workflows/qa.yml`. Ese job rechaza tres commits que ya están en `origin/2.2` porque llevan un trailer que nombra a Claude o Anthropic («vista previa del iPad 13"…», «estados con pocos datos sin huecos…», «un Nuevo registro a medias se conserva…»). Esos commits ya están publicados en 2.2: no se reescriben ni se aplastan, y el merge conserva el historial.

Qué hacer:
1. Encuentra el paso del job que revisa los trailers y cámbialo para que solo revise los commits nuevos del PR que no estén ya en ninguna rama protegida (`origin/2.2`, `origin/2.3`, `origin/1.0`), por ejemplo con `git rev-list <head> --not origin/2.2 origin/2.3 origin/1.0`. La regla sigue igual para los commits nuevos. Agrega un caso de prueba de ese chequeo si existe su banco.
2. Haz ese cambio en la misma rama del PR, empuja y espera el CI. Si sale otro rojo, arréglalo dentro de este encargo.
3. Con el CI verde, mergea el PR con merge commit (no squash ni rebase) y confirma que `git rev-list --count origin/2.3..origin/2.2` da 0, salvo lo que haya entrado a 2.2 después. Si entró algo, tráelo en el mismo PR antes de mergear.
4. Lleva el mismo arreglo del chequeo a 2.2, en un PR aparte y chico, para que no vuelva a pasar en el próximo merge. Mergéalo con CI verde.
5. Mueve a done la card «2.3 no tiene los arreglos de 2.2 de las últimas dos semanas», con evidencia: PR mergeados y el conteo.

No mergees los PR #874 ni #876. Commits y PR sin firma de IA. Si necesitas simulador y la Mini ya usa uno, usa el iPhone 14 por DeviceMCP. Es trabajo completo y autónomo: termina con `/cerrar-total`. En «Siguiente» escribe: «Ya pueden arrancar los lotes de mejoras de 2.3».

## Paso 0

- El candado sobre commits (`qa/scripts/ci-atribucion-commits.sh`) existe solo en 2.3; en 2.2 no hay ese chequeo. Asumido: el paso 4 (llevar el arreglo a 2.2) no aplica. El próximo merge de 2.2 en 2.3 corre el script de 2.3, que ya trae el arreglo; llevar el candado entero a 2.2 sería meter una regla nueva en la rama de release.
- Excluye lo publicado en 2.2, 2.3 y 1.0 salvo la rama a la que se empuja (en un push a 2.2 su propia ref ya es el commit nuevo) y la cabeza del PR. Si una rama protegida no se puede traer, no se excluye: revisar de más es el lado seguro.
- La card del merge ya estaba en done (la movió la sesión anterior antes de mergear); se le añade la evidencia.
