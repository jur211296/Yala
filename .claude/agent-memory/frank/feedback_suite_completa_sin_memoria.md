---
name: suite-completa-sin-memoria
description: Cuando la máquina no da para YalaTests entera, lo que funciona es separar el compilador de la corrida (build-for-testing + test-without-building), no lotear; y una lista de suites sacada de @Suite deja fuera 273 tipos
metadata:
  type: feedback
---

**Si `YalaTests` entera no cabe en memoria, el problema es el COMPILADOR, no los tests.** Medido el 2026-09-15,
con el sistema matando tres tandas seguidas: `build-for-testing` una vez y luego `test-without-building` por
lotes bajó el pico lo suficiente para que los diez lotes terminaran (6.876 tests en 699 suites). Lotear con
`test` a secas no sirve: cada lote vuelve a invocar el compilador, que es quien se come la memoria.

**Y la trampa que casi me deja un gate falso: una lista de suites sacada de `@Suite` pide el 64 % de la suite.**
En Swift Testing un tipo con `@Test` dentro **no necesita `@Suite`**. En este árbol hay ~6.400 anotaciones
`@Test` y **273 tipos sin `@Suite`**; mi lista tenía 488 tipos, los 8 lotes pasaron y **las pedidas cuadraron
con las ejecutadas** — porque ese control solo cubre lo que pediste. Faltaban ~2.600 tests.

**Why:** el gate se declara con un número, y un número que sale de un filtro incompleto no falla en rojo: falla
en verde. La cota honesta se saca del árbol (`grep -c '^\s*@Test'`) y se compara con la línea `Test run with N
tests in M suites` de una corrida SIN filtros.

**How to apply:**

1. `xcodebuild … build-for-testing` una vez. Si eso cabe, el resto también.
2. Intenta la suite **sin filtros** con `test-without-building`. Solo si la matan, lotea.
3. Para lotear, la lista es **todo tipo de nivel superior que contenga `@Test`**, con `@Suite` o sin él, más los
   `XCTestCase`. Suma los `Test run with` de los lotes y compáralo con la cota de `@Test`.
4. **Que clasifique el script, no tú.** Un `** TEST FAILED **` con cero líneas `Test Case` es INFRAESTRUCTURA
   (a mí fue un fichero de test nuevo que había copiado al árbol base: `git checkout -- .` no borra untracked,
   y 60 errores de compilación se leyeron como «el base también falla»). Todo bucle de medición imprime
   `casos_ejecutados` y `errores_de_compilación` por corrida, y etiqueta VEREDICTO o INFRA.

Familia de [[feedback_only_testing_filtra_por_tipo_no_por_fichero]], [[feedback_mis_mediciones_fallan_por_el_filtro]]
y [[feedback_gate_paso3_no_detecta_cero_casos]].
