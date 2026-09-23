---
name: un-arreglo-en-n-sitios-se-prueba-en-los-n
description: Un arreglo mecánico repetido en N sitios (18 ramas, 25 appliers) con un test en UNO deja 17 mutantes vivos si el gemelo viejo sigue compilando; se prueba en bucle y con un scan de la zona.
metadata:
  type: feedback
---

**Si el arreglo es el mismo gesto repetido en N sitios, el test recorre los N, y un scan de la zona fija que no quede
ninguno con la forma vieja.**

**Why:** 2026-09-23, `dangling-ref-repair-is-lost-when-its-row-cannot-be-read`. Cambié `fetch*` → `try find*` en las 18
ramas del pase final y en los 25 appliers que leen, y escribí tests para UNA rama y UN applier. 14 mutantes muertos y
aun así la lente de tests encontró 34 sitios donde volver a `fetch*` pasaba en verde: los `fetch*` tolerantes siguen
vivos (los usa `liveRowExists`) con la misma firma, y un closure que no lanza encaja en `(UUID) throws -> T?` sin aviso.
El compilador no me protegía, y mis mutantes solo tocaban el sitio que ya había testeado.

**How to apply:** antes de dar por cubierto un cambio de forma (tolerante → estricto, `try?` → `try`, un `case` en un
switch largo), pregunta si la forma vieja sigue compilando en los otros sitios. Si sí: un test en bucle sobre la lista
de sitios (con un control por sitio) más un scan que cuente las apariciones de la forma nueva contra el largo de la
lista y exija cero de la vieja. Y al elegir mutantes, pon uno en un sitio que NO sea el del test. Relacionado:
[[la-tabla-del-ticket-nombra-un-sitio-por-pantalla]], [[el-scan-de-un-modifier-no-ancla-a-que-vista-cuelga]].
