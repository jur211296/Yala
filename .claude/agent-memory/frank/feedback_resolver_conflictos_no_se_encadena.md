---
name: resolver-conflictos-no-se-encadena
description: Un script que resuelve conflictos de rebase va SOLO; `git add` + `rebase --continue` en la misma línea con `;` cerró un commit con marcas dentro. Y los .strings de Yala llevan «=======» en sus comentarios.
metadata:
  type: feedback
---

Al rebasar, el script que resuelve los conflictos va en su propia llamada, y `git add` + `rebase --continue` solo después
de comprobar a mano que no queda ninguna marca (`grep -lE "^(<<<<<<< |=======$|>>>>>>> )"`).

**Why:** el 2026-11-06 (ojo de montos del Panel) el resolvedor de los 16 `Localizable.strings` abortó a mitad y la
cadena con `;` siguió: el rebase se cerró con marcas de conflicto en 12 idiomas. Se rehízo con re-gate y `--amend`
antes del push, pero sin el `grep` posterior habría llegado al PR. El aborto vino de otra trampa: los `.strings`
usan `=======` en sus comentarios de cabecera, así que comprobar «no queda `=======`» sin anclar a línea entera falla
siempre.

**How to apply:** resolver → comprobar marcas ancladas (`^=======$`) y `plutil -lint` → solo entonces `git add` y
continuar, cada paso con `&&` o en llamadas separadas. Dos sesiones que añaden claves al final de los `.strings`
chocan siempre: se quedan las dos tandas. Relacionado: [[sin-firma-de-ia-en-commits]].
