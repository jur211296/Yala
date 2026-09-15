---
name: xcuitest-completo-por-lotes
description: La suite XCUITest entera dura más que cualquier espera del harness — se corre por lotes en UN proceso de fondo, se cuenta por CLASE, y el conjunto del gate se CALCULA con los codeGlobs
metadata:
  type: reference
---

**La suite XCUITest completa de Yala no cabe en una sola llamada, y el modo de fallo no se parece a un
fallo de test.**

**Qué pasó (2026-09-10):** lancé `-only-testing:YalaUITests` entero. Tarda **más de 40 min**, así que la
llamada se fue a background; encima acumulé cuatro wrappers `until … sleep` esperándola, y el harness
mató **todos** los procesos de fondo por memoria (`system is running low on memory`). Con ellos se fue
`xcodebuild`, y el log terminó en **`** BUILD INTERRUPTED **`** con 118 casos en verde y la suite a
medias.

**Cómo se clasifica ese log, que es lo que ahorra el diagnóstico:**

- `BUILD INTERRUPTED` **no es un veredicto**: es una muerte externa. No hay nada que arreglar en el
  código. Distinto del `Restarting after unexpected exit` de la colisión de dos corridas
  (`.claude/rules/testing.md`), y distinto de un rojo de test.
- Los `Test Case … passed` que YA salieron **sí valen**: cada uno es un veredicto individual. Lo que
  falta es cobertura, no confianza.
- Comprobar `grep -c "Restarting after unexpected exit"`: si da 0, ningún caso se repitió ni se perdió a
  mitad.

**Cómo correrla, entonces:**

1. **Por lotes en PRIMER PLANO**, 4-6 clases por llamada, cada una bajo el timeout de la herramienta.
   Nada de background: es lo que se muere.
2. **La cobertura se cuenta por CLASE, no por casos.** El total de casos varía; el de clases no:

       grep -rhoE "^final class ([A-Za-z0-9_]+): XCTestCase" YalaUITests --include="*.swift" \
         | sed 's/final class //; s/: XCTestCase//' | sort > all.txt
       grep -oE "Test Case '-\[YalaUITests\.[A-Za-z0-9_]+ " <log> \
         | sed 's/.*YalaUITests\.//; s/ $//' | sort -u > ran.txt
       comm -23 all.txt ran.txt      # lo que falta

   El 2026-09-10 eran **61 clases** y la corrida interrumpida había cubierto 53. Las 8 que faltaban
   incluían justo las dos del Welcome, que eran las que el cambio tocaba.
3. **`bash qa/scripts/sim-libre.sh` antes de cada lote.** Un lote nuevo mientras otro corre es la
   colisión de dos runners, y esa sí produce rojos que parecen tuyos.
4. **Si tocas código entre lotes, dilo en el informe.** Un lote corrido sobre el árbol anterior no
   verifica el árbol final, por mucho que el cambio «no pueda afectarle»: eso es un razonamiento, no una
   medición. Lo honesto es repasar las áreas plausibles sobre el código final y escribir la distinción.

**Tres cosas más, medidas el 2026-09-11 corriendo las 62 clases enteras:**

- **El timeout de la herramienta Bash tiene un tope real de 600 s**, aunque le pases 3 000 000 ms: pasado
  ese minuto y medio de más, la llamada se va a background igual. O sea que «lotes en primer plano» no es
  una opción del que llama — un lote de 6 clases dura ~12 min y SIEMPRE acaba de fondo. Lo que sí se puede
  es lanzar **un solo** proceso de fondo y esperar su notificación, que es lo que evita la muerte por
  memoria de la tanda del 10-sep: el problema nunca fue el background, fue acumular cuatro.
- **`Failed to create a bundle instance representing …` es un fallo del RUNNER, no un rojo.** Sale con
  `passed=0 failed=0` y `clases=0/N`: cero casos ejecutados. Repetir el lote lo arregló entero, con el
  disco en 26 GB. Clasifícalo con `BUILD INTERRUPTED`, no con un test en rojo.
- **Cuenta los rojos con `Test Case.*' failed`, no con `' failed`.** El segundo también casa con las
  líneas `Test Suite '…' failed` y convierte UN caso rojo en «4 fallos» en tu propio informe.

**Y cuándo toca la suite (casi) entera: lo decide el cruce, no el criterio (2026-09-15).** Tras la compactación
iba a sellar con las 13 clases que había elegido a criterio (12 del cruce y una de fuera); el paso 3 del gate cruza los ficheros tocados con los `codeGlobs`
de `qa/coverage-index.json`, y `ContentView.swift` y `ProfileView.swift` caen en 45 áreas: eran **47 clases**, 35 sin correr.
Las 35 que faltaban corrieron en 9 lotes de 4 en UN proceso de fondo (`uilotes.sh`: secuencial, reanudable,
`stdin` a `/dev/null` para que el lote no se coma el fichero de lotes). ⇒ **calcula el conjunto con un
script** (globs con `glob.glob(recursive=True)`, clases del campo `coverage` que existan como fichero) y
compáralo con lo corrido ANTES de sellar. Y el `lastVerified` solo se sube en las áreas cuyas clases citadas
corrieron TODAS: un área con una clase sin correr se queda con su fecha.

Relacionado: [[dos-corridas-un-simulador]], [[el-arbol-base-contesta-si-es-mio]].
