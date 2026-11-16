---
name: reference-tema-claro-de-yala-en-el-simulador
description: Para capturar Yala en tema claro, `simctl ui appearance light` no basta; se lanza con `-userTheme 1` (AppTheme.light).
metadata:
  type: reference
---

El tema de Yala no sigue la apariencia del simulador: lo guarda la app en `userTheme` (`ThemeManager`,
`AppTheme` en `UIHelpers.swift`; por defecto Liquid Glass, que pinta oscuro). Con `xcrun simctl ui <udid>
appearance light` la captura salió igual de oscura (medido el 2026-11-11, lote 11 de la zona 41).

Lo que funciona: lanzar con `-userTheme 1` (`extraArguments:` en `launchForUITest`). 0 = sistema, 1 = Claro,
2 = Oscuro, 3-8 = Índigo, Rosa, Teal, Minimalista, Translúcido, Liquid Glass.

**How to apply:** cuando un hallazgo dice «en el tema claro no llega a AA», la captura del antes y el después va con
`-userTheme 1`, no con la apariencia del sistema. Relacionado: [[feedback-diff-de-pixeles-en-la-misma-sesion]].
