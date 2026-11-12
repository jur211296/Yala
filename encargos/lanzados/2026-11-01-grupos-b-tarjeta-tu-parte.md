# Grupos B · 4: construir el componente de la tarjeta «Tu parte» con sus líneas y la hoja de una línea (Gasto | Recarga)

Contexto: Grupos opción B, acordada con Jürgen el 1-nov. Manda docs/disenos/grupos-tu-parte-en-lineas/README.md, sección «Versión final acordada» (maquetas: https://claude.ai/artifact/7r4utQ1genzSPEzmPJzutV). El diseño técnico del puente está en tickets/in-progress/grupos-tu-parte-en-lineas.md. Las reglas de las líneas (GroupSplitLinesRecipe) ya están en 2.2 con tests. La tarjeta 1 (las líneas viajan por iCloud y la nube) está mergeada; las tarjetas 2 y 3 (el puente crea tus registros desde las líneas y la recarga no cuenta) están en el PR #737, en cola de merge a 2.2. Card del tablero: «Grupos B · 4 · Tarjeta "Tu parte" y hoja de línea (componente)».

Qué hacer:
1. Componente SwiftUI de la tarjeta «Tu parte»: sus líneas, «Añadir línea» y el estado «Cuadra ✓» / «Faltan S/ X». Valida con GroupSplitLinesRecipe, sin duplicar reglas.
2. La hoja de una línea con el segmento Gasto | Recarga; la recarga pide la cuenta destino. Condición del puente (PR #737): la cuenta destino tiene que ser tuya, no de sistema y en la divisa del gasto; si no, el puente deja tu parte en una sola línea sin avisar. Por eso el selector solo ofrece esas cuentas.
3. Textos en los 16 idiomas. Sigue estrictamente el sistema de diseño (tokens, componentes existentes).
4. Previews y tests de la lógica del componente.

Qué no tocar: no cablearlo todavía a ninguna pantalla (eso es de las tarjetas 5 y 6). No cambies el puente ni la lógica de Estadísticas. Si para compilar necesitas código del PR #737 que aún no esté en 2.2, espera a que mergee y rebasa; no lo copies.

Hecho cuando: el componente tiene previews y tests de su lógica en verde, y hay capturas claro/oscuro con Dynamic Type grande en el PR.

Rama base 2.2. Antes de abrir el PR, revisa que el CI del PR anterior (#737) haya terminado y rebasa sobre 2.2 si ya mergeó.
Simulador: pipeline serial de Yala, uno a la vez; al terminar, apaga y borra los simuladores que usaste. Limpia el DerivedData de tu worktree y las cachés de XcodeBuildMCP al cerrar (la Mini anda con unos 21 GB libres).
Si aparece una decisión de diseño no cubierta por la «Versión final acordada», elige la opción más fiel al README, anótala en el PR y sigue.

Esta sesión termina con /cerrar-total (cierre autónomo, cierra-sola).

## Paso 0

Decisiones tomadas al arrancar (sesión autónoma; las de diseño, por fidelidad al README «Versión final acordada» y a la
maqueta `opcion-b.html`, escenarios 1-3 y 7).

- **Base.** 2.2 en `eda39023b`. El componente no necesita nada del PR #737: usa `GroupSplitLinesRecipe` (ya en 2.2)
  y la condición del destino se reproduce en la lógica del componente, sin copiar el puente.
- **Ficheros.** `Yala/App/Logic/GroupSplitLinesEditorLogic.swift` (lógica pura) ·
  `Yala/App/Views/Groups/SplitLines/GroupSplitLinesCard.swift` (tarjeta) ·
  `Yala/App/Views/Groups/SplitLines/GroupSplitLineSheet.swift` (hoja de una línea) · `Yala/Utils/L10n.swift` + los 16
  `Localizable.strings` · `YalaTests/Groups/GroupSplitLinesEditorLogicTests.swift` · `qa/coverage-index.json`.
- **API.** La tarjeta recibe `@Binding var lines`, tu parte (`Decimal`), la divisa, el nombre de la cuenta de la que
  sale una recarga («Grupos» si pagó otro, la cuenta con la que pagaste si pagaste tú) y esa cuenta para excluirla del
  destino. Expone `GroupSplitLinesEditorLogic.canSave` para que las tarjetas 5 y 6 enciendan «Guardar»/«Aprobar».
- **Reglas, sin duplicar.** Problemas, cuadre y «se puede guardar» salen de `GroupSplitLinesRecipe`. Lo único propio:
  si el destino de una recarga es elegible (no de sistema, no archivada, misma divisa: la condición del puente del
  #737) y el texto del importe → `Decimal`.
- **Destino.** `AccountSelectorSheet` con `currencyFilter` = divisa del gasto y `excludeAccount` = cuenta de origen: ya
  quita las de sistema y las archivadas. Una línea guardada con un destino que dejó de servir (otro aparato, cuenta
  archivada) sale marcada y bloquea guardar, para que el puente no la aplane sin avisar.
- **Empezar a partir.** `initialLines(share:subcategoryID:)` = una línea de gasto por tu parte entera con la categoría
  que hubiera (maqueta 1: «cambias la primera línea a Recarga»). «Añadir línea» abre la hoja con lo que falta.
- **No previsto en el README (elijo y lo anoto en el PR):** (1) sobra dinero → «Sobran S/ X», paralelo a «Faltan»;
  (2) borrar una línea: «Eliminar línea» en su hoja, solo si quedan otras (sin líneas no hay receta); (3) sin el
  contador «2 líneas» de la maqueta: las filas ya se ven debajo y evita un plural sin `.stringsdict` en las variantes;
  (4) la frase de la recarga es genérica («Pasa a tu cuenta Sip. No cuenta como gasto ni como ingreso.»): el «lo que
  debes a Pía no cambia» depende de la pantalla que la monte.
- **Capturas.** Un enganche `#if DEBUG` temporal que monta una galería del componente y un XCUITest conductor
  temporal; los dos se retiran antes del `/gate`. No hay «antes»: el componente no existía.
- **Strings.** Se insertan tras `groups.expense.overAllocated %@`, no al final del fichero, para no chocar con el #737,
  que añade al final.
