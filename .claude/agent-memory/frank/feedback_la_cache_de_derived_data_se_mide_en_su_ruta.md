---
name: la-cache-de-derived-data-se-mide-en-su-ruta
description: Medir en local si una caché de DerivedData sirve al CI — restáurala en la MISMA ruta y con el mismo checkout de ruta; copiarla a otra da un falso «no sirve».
metadata:
  type: feedback
---

**Una caché de DerivedData se prueba restaurándola en la misma ruta que la generó.** El 21-nov, para
decidir la caché del CI, copié `dd1` a `dd-b0` y compilé contra la copia: 241 s, más que en frío
(214). Concluí «la caché no sirve» y casi la descarto. Era el experimento: la ruta del DerivedData
está dentro de todo lo cacheado (intermedios, módulos, claves). En la misma ruta, con un checkout
nuevo (inodos y fechas nuevas): **23 s**.

**Why:** el CI restaura siempre en `/Users/runner/work/Yala/Yala/.ddp`; un experimento con otra ruta
mide una situación que el CI nunca vive. Y el falso negativo era convincente porque el número salía
limpio.

**How to apply:**
- Para simular el CI: mueve el DerivedData usado a un lado y clona la base a la ruta original
  (`cp -c -R`, APFS, instantáneo); el checkout nuevo, en la misma ruta con `git archive`.
- Mide varios tipos de cambio, no uno: cuerpo de una vista 47 s, solo un test 65 s, interfaz de un
  fichero central 192 s. Un solo cambio «de interfaz» habría dicho «−10 %».
- La caché de compilación de Xcode (`CompilationCache.noindex`) sola no basta: 218 s. Necesita el
  resto del DerivedData.

Relacionado: [[el-ci-se-verifica-en-local]] · [[mis-mediciones-fallan-por-el-filtro]].
