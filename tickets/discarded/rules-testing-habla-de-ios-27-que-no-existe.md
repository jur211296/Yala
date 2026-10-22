---
id: rules-testing-habla-de-ios-27-que-no-existe
status: discarded
priority: medium
area: testing
created: 2026-09-07
updated: 2026-10-07
source: medido de camino en rojo-xcuitest-runner-muere-tras-el-primer-caso
---

# `.claude/rules/testing.md` da por vigente un iOS 27.0 que esta máquina no tiene

Why: Discarded 2026-10-07, con OK de Jürgen (2026-10-07, 21:50 Lima). La premisa se invirtió: esta Mac ya tiene iOS 27.0 (`xcrun simctl list runtimes` el 2026-10-07 da `iOS 27.0 (27.0 - 24A434)`, con un `iPhone 17 Pro` creado en él), así que la regla de `.claude/rules/testing.md` vuelve a describir este equipo.

## Lo medido (2026-09-07)

```
$ xcrun simctl list runtimes | grep -i ios
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
$ xcodebuild -version → Xcode 26.6 (17F113)
$ xcrun --show-sdk-version → 26.5
```

**Hay un solo runtime: iOS 26.5.** No existe ningún 27.0.

La regla de entorno abre diciendo: «**Hoy se compila contra `iPhoneSimulator27.0` ⇒ hace falta un
device de iOS 27.0**», y de ahí cuelgan cuatro bullets más sobre 27.0: que es ~2× más lento, que
cuelga el teardown ~600 s, que ningún swipe sintético materializa una celda de `LazyVGrid`, y que la
primera corrida tras bootear «en iOS 27.0 falla de verdad». El `.xctestrun` que genera hoy el build
se llama `…_iphonesimulator26.5-arm64.xctestrun`.

## Por qué importa y no es cosmético

Es la **primera** sección que lee quien diagnostica un rojo de entorno, y manda comprobar una
condición que no puede cumplirse. Dos de esas reglas prescriben trabajo (aterrizar por deeplink en
vez de scrollear; calibrar umbrales «en 27.0, no en 26.x») apoyándose en mediciones de un runtime
que ya no está instalado. El `MEMORY.md` de proyecto lo registra desde el **2026-07-28** («esta Mac
ya NO tiene Xcode-beta ni runtime iOS 27.x»), o sea que la regla lleva ~6 semanas desactualizada.

No se tocó al pasar porque es otro objeto que el ticket que lo encontró.

## Qué haría falta

Decidir para cada bullet de 27.0 si (a) se archiva como histórico fechado, (b) se re-mide en 26.5, o
(c) se conserva porque la otra Mac sí tiene 27.0 — y en ese caso decirlo, que hoy se lee como si
fuera este equipo. Empezar por la frase del SDK, que es la que manda comprobar algo imposible.

## Relacionados

- [[rojo-xcuitest-runner-muere-tras-el-primer-caso]] — lo encontró al verificar la premisa del entorno
