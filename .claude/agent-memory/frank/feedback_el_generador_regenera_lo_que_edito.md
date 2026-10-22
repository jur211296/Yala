---
name: el-generador-regenera-lo-que-edito
description: Un generador que sincroniza derivados hay que re-correrlo DESPUÉS de editar a mano, no solo antes. El orden equivocado me dejó dos locales con el texto viejo y un marcador sin traducir, y solo lo vi porque miré la pantalla.
metadata:
  type: feedback
---

**Cuando una herramienta genera o sincroniza ficheros derivados, el orden es: generar → editar a mano →
RE-GENERAR.** Saltarse el tercer paso deja los derivados apuntando a la versión anterior.

**Why:** el 2026-09-07 di de alta tres claves nuevas con el script de l10n, y después edité los
`.strings` a mano para poner las traducciones reales. Dos de los locales son **copias regeneradas** de
otros, y el script las sincroniza al final de su ejecución — que ya había pasado. Resultado: dos idiomas
sirviendo el texto viejo y un marcador de «sin traducir» vivo, con el fichero fuente ya correcto.

**Lo que lo cazó no fue ninguna comprobación mía, fue la captura de pantalla**: el simulador mostraba un
título que ya no existía en el código. Si hubiera dado por buena la lectura del fuente, eso viaja al PR.

**How to apply:**

- **Antes de dar por cerrada una edición sobre ficheros que un script genera o copia, re-corre el
  script.** Suelen ser idempotentes precisamente para esto, así que correrlo de más no cuesta nada y
  correrlo de menos cuesta un bug silencioso.
- **La pregunta que lo detecta:** «¿alguno de los ficheros que acabo de editar es COPIA de otro?». Si la
  respuesta es sí, o no lo sé, re-correr.
- **Y el corolario que vale para todo:** *si citas una línea, cítala del árbol en el que estás* aplica
  también a lo que la app **muestra**. El fuente correcto no garantiza la pantalla correcta cuando hay
  un derivado en medio. Verlo en pantalla no es ceremonia.

Relacionado: [[capturas-simulador-para-la-web]] · [[mis-mediciones-fallan-por-el-filtro]].
