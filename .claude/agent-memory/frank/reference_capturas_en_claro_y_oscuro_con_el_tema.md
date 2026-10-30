---
name: reference-capturas-en-claro-y-oscuro-con-el-tema
description: Para capturas claro/oscuro de Yala, `simctl ui appearance` no sirve (el tema de fábrica fuerza oscuro); se fija `userTheme` con defaults write antes de lanzar
metadata:
  type: reference
---

`xcrun simctl ui <udid> appearance light` no cambia nada en Yala: el tema de fábrica (Liquid Glass) fuerza su
esquema con `.preferredColorScheme`. Las dos tandas «claro» y «oscuro» salieron oscuras el 2026-10-30 (PR #700).

Lo que funciona, sin recompilar el conductor XCUITest:
`xcrun simctl spawn <udid> defaults write com.jurgenschmidt.yala.dev userTheme -int 1` (Claro) o `-int 2` (Oscuro)
antes de cada `test-without-building`. `-uitest-reset` no la borra. Al acabar, `defaults delete … userTheme`.

Así se saca también el «antes» con el binario viejo ya compilado, antes de recompilar con el cambio.
Relacionado: [[feedback-capturas-con-conductor-xcuitest]].
