---
name: project-uso-de-linea-espera-decision
description: 22-nov-2026 — el «uso de línea» de la hoja de cuenta (decisión 117) espera a Jürgen; el resto del lote quedó en PR borrador.
metadata:
  type: project
---

El «% usado · disponible de» de la hoja de cuenta (referencia del 17-nov) necesita guardar la línea de crédito de cada
tarjeta, y `Account` no tiene ese campo. El encargo del 22-nov (Novedades 2.3, llegada del Panel, nota «lo que te queda»)
lo dejó en card «Espera decisión»: A campo nuevo sincronizado (recomendada, Dan despliega iCloud de producción), B sin
uso de línea, C solo en el aparato.

**Why:** un campo nuevo toca modelo, esquema de producción de iCloud y nube de Yala, y quedaba fuera del `toca:`; en
nocturno eso no se decide solo. Por la regla nocturna el PR del lote entero quedó en borrador, sin merge.

**How to apply:** si Jürgen elige A, es un encargo nuevo (no reabrir el PR del lote); si elige B o C, el PR borrador se
puede mergear tal cual. Antes de actuar, mira la card y el PR: pueden haber cambiado. Ver [[feedback-autonomo-hasta-el-final]].
