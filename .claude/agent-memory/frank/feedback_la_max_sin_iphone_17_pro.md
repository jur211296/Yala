---
name: la-max-sin-iphone-17-pro
description: En la Max falta a veces el simulador «iPhone 17 Pro» que el gate pide por nombre (2026-11-04 y 2026-11-13, esta vez sin ningún device); se crea en iOS 27.2
metadata:
  type: reference
---

El 2026-11-04 la Max solo tenía la tanda por defecto (iPhone 17, 17e, 18 Pro, Air, Duo) en iOS 27.2: `-destination name=iPhone 17 Pro` del `/gate` no casaba con nada. Se creó con `xcrun simctl create "iPhone 17 Pro" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2` (UDID 52204681-…). Antes de un gate en la Max, `xcrun simctl list devices | grep "iPhone 17 Pro ("`; si sale más de uno, usa `id=`.

**Se repitió el 2026-11-13**, peor: `simctl list devices` no traía NINGÚN device (solo los dos runtimes 27.2). Se volvió a
crear con el mismo comando (UDID 1B89D86B-…) y las corridas fueron por `id=`. Mira antes de lanzar nada; si falta, créalo y
sigue: no es una avería de la sesión.
