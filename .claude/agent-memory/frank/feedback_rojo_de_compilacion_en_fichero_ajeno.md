---
name: rojo-de-compilacion-en-fichero-ajeno
description: Un error de tipos en un fichero que no tocaste, tras un build incremental, puede ser del compilador — recompila una vez antes de bisecar tu diff
metadata:
  type: feedback
---

Un build incremental de `Yala Dev` (Xcode 27, `-jobs 2`) cayó con cinco errores en `ImportIntroSheet.swift:440`
(«Dictionary requires that 'Category' conform to 'Hashable'»), un fichero que el diff no tocaba. El mismo árbol, sin
cambiar nada, compiló limpio en el build siguiente.

**Why:** 2026-10-22, sesión B del lote 2.2 · 02. Gasté un rato buscando qué nombre nuevo del diff sombreaba `Category`
antes de probar lo barato.

Segunda vez, 2026-10-24 (encargo de las tartas sin categoría): «Set requires that 'Category' conform to 'Hashable'» en
`PanelFilterControlBar.swift:134`, código sin tocar, con `-destination 'generic/platform=iOS Simulator'` (compila
x86_64 además de arm64). Relanzado con el destino del simulador por id (solo arm64), compiló limpio. Mismo tipo
(`Category`, conformidad `Hashable` de `@Model`), mismo patrón: el compilador, no el diff.

**How to apply:** si el rojo está en un fichero que no tocaste y el mensaje no tiene que ver con tu cambio, relanza el
build tal cual antes de bisecar, y mejor con `-destination 'platform=iOS Simulator,id=<udid>'` (una sola arquitectura,
más rápido). Si se repite, entonces sí es tuyo. Relacionado: [[regresion-aparente-se-mide-contra-la-base]].
