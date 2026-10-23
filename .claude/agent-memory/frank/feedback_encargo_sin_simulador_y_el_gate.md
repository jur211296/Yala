---
name: encargo-sin-simulador-y-el-gate
description: Un encargo que prohíbe el simulador choca con el gate (unit y XCUITest corren dentro); Jürgen aprueba usarlo solo para el gate, en cola
metadata:
  type: feedback
---

Cuando un encargo dice «sin simulador» y hay código que commitear, el `/gate` lo necesita igual: los unit tests también
se instalan y corren dentro del simulador. No se decide solo ni se salta el gate: se pregunta. El 2026-10-23 Jürgen eligió
«simulador solo para el gate» (unit + XCUITest acotados, en cola con `sim-lock.sh`, sin conducir la app ni capturas)
frente a «que lo pruebe el CI» o «esperar sin PR».

**Why:** la prohibición protege a la otra sesión viva (comparte el simulador); el candado ya resuelve eso, y sin PR el
gate es la única red.

**How to apply:** en el Paso 0 de un encargo sin simulador que vaya a tocar código, anticipa la pregunta en vez de
descubrirla al final; propón la opción del gate en cola como recomendada. Las capturas antes/después siguen fuera.
Relacionado: [[el-carril-espera-a-cola-a]].
