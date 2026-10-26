---
name: rojo-de-compilacion-en-fichero-ajeno
description: Error de tipos en un fichero ajeno tras build incremental (`Category` no Hashable) es del compilador — relanza; si repite, clean antes de bisecar
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

Tercera vez, 2026-10-25 (lote 12.2): el mismo `PanelFilterControlBar.swift:134`, ya con destino por id, y relanzar NO
lo curó (dos rojos seguidos). Había editado ficheros mientras un `xcodebuild test` compilaba ese DerivedData. `clean` +
build: verde, sin tocar el diff.

**How to apply:** si el rojo está en un fichero que no tocaste y el mensaje no tiene que ver con tu cambio, relanza el
build tal cual antes de bisecar, con `-destination 'platform=iOS Simulator,id=<udid>'`. Si se repite y editaste el árbol
durante un build anterior, `clean` antes de bisecar. Solo si cae también limpio es tuyo. Relacionado: [[regresion-aparente-se-mide-contra-la-base]].

**Cuarta vez, 2026-10-26 (S6, ajuste kjzs sobre #634): ni relanzar ni `clean` lo curaron.** Mismo
`PanelFilterControlBar` (`Set(selectedSubsByID.compactMap { $0.category })`), tres rojos seguidos, el último en limpio
y por id. El body había crecido con #634 y Xcode 27.1 dejó de ver ahí la conformidad. Se quitó el `Set` de modelos
(`distinctParents`, deduplica por `persistentModelID`) y compiló. ⇒ si cae limpio, no bisecar el diff: sacar el `Set`/
`Dictionary` de `@Model` del `body` a un helper.
