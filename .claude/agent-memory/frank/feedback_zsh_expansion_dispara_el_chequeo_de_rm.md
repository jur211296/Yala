---
name: zsh-expansion-dispara-el-chequeo-de-rm
description: Una expansión de zsh como ${(f)"$(…)"} hace que el chequeo de seguridad de Bash rechace el comando aunque no haya ningún rm; el filtro -only-testing se arma en un script bash 3.2 sin mapfile.
metadata:
  type: feedback
---

Para pasar N filtros `-only-testing` a `xcodebuild`, no armes el array en línea con expansiones de zsh
(`FILES=(${(f)"$(grep …)"})`): el chequeo de seguridad de Bash no sabe leerlo y lo rechaza como «rm peligroso»
sin que haya ningún `rm`. Tampoco `mapfile`: la bash de macOS es 3.2 y no lo tiene.

**Why:** 12-nov-2026, lote 2.3 de Estadísticas: dos intentos perdidos, uno rechazado por el chequeo y otro
muerto con «mapfile: command not found».

**How to apply:** script en el scratchpad con `FILES=(); while IFS= read -r f; do FILES+=("$f"); done < <(…)`
y luego `"${ONLY[@]}"`; se corre con `bash script.sh`. Relacionado: [[only-testing-filtra-por-tipo-no-por-fichero]].
